import Foundation

/// Recorder row whose combo just changed. The binding carries
/// the recorder-only runtime action, which can intentionally
/// differ from other staged edits in the Settings model.
public struct LiveKeybindingTarget: Sendable {
    public let mode: String
    public let binding: KeyBinding

    public init(mode: String, binding: KeyBinding) {
        self.mode = mode
        self.binding = binding
    }
}

/// Honest recorder feedback. Only `.active` means Carbon
/// registered this exact action in the runtime-active mode.
public enum LiveKeybindingApplyStatus: Equatable, Sendable {
    case active
    case inactiveMode(String)
    case denied
    case profileShadowed
    case compileFailed
}

/// A live apply can fail before changing the running table.
public enum LiveKeybindingApplyError: Error, Equatable,
    Sendable
{
    case unmanaged
    case unavailable
    case unreadableConfig
    case unreadableProfile
    case preparationFailed
    case superseded
}

/// In-memory rollback point captured before the first recorder
/// mutation. It survives a deleted/corrupt sidecar, avoiding a
/// clean Settings model with ghost hotkeys still registered.
public struct LiveKeybindingSnapshot: Sendable {
    let modes: [KeyMode]
    let activeMode: String
    let generation: UInt64

    /// The resolved key modes currently installed — read by the
    /// read-only shortcuts reference panel (#326). The rollback
    /// token (`generation`) stays internal; only the display data
    /// is exposed.
    public var keyModes: [KeyMode] { modes }
    /// The runtime-active mode's name.
    public var activeModeName: String { activeMode }
}

extension KiwiCore {
    /// Captures the effective, successfully compiled structured
    /// bindings currently installed. nil means live apply is
    /// outside the current ownership/VM state.
    public func liveKeybindingSnapshot()
        -> LiveKeybindingSnapshot?
    {
        guard isGuiManaged, keys.lua != nil,
            let modes = appliedStructuredModes
        else { return nil }
        return LiveKeybindingSnapshot(
            modes: modes,
            activeMode: keys.currentMode,
            generation: keybindingRuntimeGeneration
        )
    }

    /// Applies recorder-only base modes through the active
    /// profile override, without persistence. Preparation is
    /// complete before one manager swap. The target result is
    /// scoped to its effective action and runtime mode; absence
    /// from `activationFailures` alone never proves success.
    public func liveApplyKeybindings(
        modes base: [KeyMode],
        target: LiveKeybindingTarget?
    ) -> Result<
        LiveKeybindingApplyStatus?,
        LiveKeybindingApplyError
    > {
        guard isGuiManaged else { return .failure(.unmanaged) }
        guard let lua = keys.lua else {
            return .failure(.unavailable)
        }
        // A recorder must disarm before it commits (see
        // KeyRecorderField.finish). While suspended nothing is
        // registered, so `activationFailures` is empty and a
        // status read here would falsely claim `.active`. Refuse
        // rather than lie — this is the enforced tripwire behind
        // that ordering invariant (#213).
        guard !keys.isSuspended else { return .failure(.unavailable) }
        let profile: KeyModeOverride?
        switch activeProfileModesForLiveApply() {
        case .success(let modes):
            profile = modes
        case .failure(let error):
            return .failure(error)
        }

        let resolved = ConfigResolver.resolvedModes(
            base: base,
            profile: profile
        )
        let shadowed =
            target.map {
                effectiveBinding(for: $0, in: resolved)?
                    .sameAction(as: $0.binding) != true
            } ?? false
        let prepared = prepareKeybindings(resolved, lua: lua)

        // A target action that cannot compile must leave the
        // previously working table intact. Release every newly
        // minted ref; no manager mutation has happened yet.
        if let target,
            !shadowed,
            prepared.failures.contains(where: {
                $0.mode == target.mode
                    && $0.binding.sameAction(
                        as: target.binding
                    )
            })
        {
            prepared.release(using: lua)
            return .success(.compileFailed)
        }

        let active = keys.currentMode
        install(prepared, preferredMode: active)
        guard let target else { return .success(nil) }
        if shadowed { return .success(.profileShadowed) }
        guard target.mode == keys.currentMode else {
            return .success(.inactiveMode(target.mode))
        }
        guard let combo = KeyCombo.parse(target.binding.combo)
        else { return .success(.compileFailed) }
        if keys.activationFailures.contains(combo) {
            return .success(.denied)
        }
        return .success(.active)
    }

    /// Re-applies persisted base + active-profile bindings. A
    /// reload/discard path tries this first so a successful Save
    /// adopts the new file rather than restoring the old snapshot.
    public func restoreSavedLiveKeybindings()
        -> Result<Void, LiveKeybindingApplyError>
    {
        guard isGuiManaged else { return .failure(.unmanaged) }
        guard let lua = keys.lua else {
            return .failure(.unavailable)
        }
        guard let config = loadStructuredConfig() else {
            return .failure(.unreadableConfig)
        }
        let profile: KeyModeOverride?
        switch activeProfileModesForLiveApply() {
        case .success(let modes):
            profile = modes
        case .failure(let error):
            return .failure(error)
        }
        let resolved = ConfigResolver.resolvedModes(
            base: config.modes,
            profile: profile
        )
        let prepared = prepareKeybindings(resolved, lua: lua)
        install(prepared, preferredMode: keys.currentMode)
        return .success(())
    }

    /// Disk-independent rollback fallback. Snapshot sources were
    /// previously compiled; any preparation failure now aborts
    /// and leaves the current table untouched for a later retry.
    public func restoreLiveKeybindings(
        _ snapshot: LiveKeybindingSnapshot
    ) -> Result<Void, LiveKeybindingApplyError> {
        guard snapshot.generation == keybindingRuntimeGeneration
        else { return .failure(.superseded) }
        guard let lua = keys.lua else {
            return .failure(.unavailable)
        }
        let prepared = prepareKeybindings(
            snapshot.modes,
            lua: lua
        )
        guard prepared.failures.isEmpty else {
            prepared.release(using: lua)
            return .failure(.preparationFailed)
        }
        install(
            prepared,
            preferredMode: snapshot.activeMode
        )
        return .success(())
    }

    /// Suspends every KiwiDesk Carbon hotkey while a Settings
    /// recorder is armed (#213), so pressing an existing shortcut
    /// to test it can't fire its action. Paired with
    /// `resumeHotkeysForRecording()` when capture ends. Suspend/
    /// resume round-trip the exact table, so both are safe no-ops
    /// when nothing is registered; system shortcuts are untouched.
    public func suspendHotkeysForRecording() {
        keys.suspend()
    }

    public func resumeHotkeysForRecording() {
        keys.resume()
    }

    private func activeProfileModesForLiveApply()
        -> Result<KeyModeOverride?, LiveKeybindingApplyError>
    {
        guard let name = profiles.currentName else {
            return .success(nil)
        }
        do {
            return .success(try profiles.read(name: name).modes)
        } catch {
            onLog(
                "structured: active profile '\(name)' "
                    + "unreadable — live keybinding apply "
                    + "cancelled"
            )
            return .failure(.unreadableProfile)
        }
    }

    private func effectiveBinding(
        for target: LiveKeybindingTarget,
        in modes: [KeyMode]
    ) -> KeyBinding? {
        modes.first(where: { $0.name == target.mode })?
            .bindings.last(where: {
                KeyCombo.equivalent(
                    $0.combo,
                    target.binding.combo
                )
            })
    }
}
