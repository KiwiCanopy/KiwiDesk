import Foundation

/// Recorder row whose combo just changed. The binding carries
/// the recorder-only runtime action, which can intentionally
/// differ from other staged edits in the Settings model.
public struct LiveKeybindingTarget: Sendable {
    public let layer: String
    public let binding: KeyBinding

    public init(layer: String, binding: KeyBinding) {
        self.layer = layer
        self.binding = binding
    }
}

/// Honest recorder feedback. Only `.active` means Carbon
/// registered this exact action in the runtime-active mode.
public enum LiveKeybindingApplyStatus: Equatable, Sendable {
    case active
    case inactiveLayer(String)
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
    let layers: [KeyLayer]
    let activeLayer: String
    let generation: UInt64

    /// The resolved key modes currently installed — read by the
    /// read-only shortcuts reference panel (#326). The rollback
    /// token (`generation`) stays internal; only the display data
    /// is exposed.
    public var keyLayers: [KeyLayer] { layers }
    /// The runtime-active mode's name.
    public var activeLayerName: String { activeLayer }
}

extension KiwiCore {
    /// Captures the effective, successfully compiled structured
    /// bindings currently installed. nil means live apply is
    /// outside the current ownership/VM state.
    public func liveKeybindingSnapshot()
        -> LiveKeybindingSnapshot?
    {
        guard isGuiManaged, keys.lua != nil,
            let layers = appliedStructuredLayers
        else { return nil }
        return LiveKeybindingSnapshot(
            layers: layers,
            activeLayer: keys.currentLayer,
            generation: keybindingRuntimeGeneration
        )
    }

    /// Applies recorder-only base modes through the active
    /// profile override, without persistence. Preparation is
    /// complete before one manager swap. The target result is
    /// scoped to its effective action and runtime mode; absence
    /// from `activationFailures` alone never proves success.
    public func liveApplyKeybindings(
        layers base: [KeyLayer],
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
        let profile: KeyLayerOverride?
        switch activeProfileLayersForLiveApply() {
        case .success(let modes):
            profile = modes
        case .failure(let error):
            return .failure(error)
        }

        let resolved = ConfigResolver.resolvedLayers(
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
                $0.layer == target.layer
                    && $0.binding.sameAction(
                        as: target.binding
                    )
            })
        {
            prepared.release(using: lua)
            return .success(.compileFailed)
        }

        let active = keys.currentLayer
        install(prepared, preferredLayer: active)
        guard let target else { return .success(nil) }
        if shadowed { return .success(.profileShadowed) }
        guard target.layer == keys.currentLayer else {
            return .success(.inactiveLayer(target.layer))
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
        let profile: KeyLayerOverride?
        switch activeProfileLayersForLiveApply() {
        case .success(let modes):
            profile = modes
        case .failure(let error):
            return .failure(error)
        }
        let resolved = ConfigResolver.resolvedLayers(
            base: config.layers,
            profile: profile
        )
        let prepared = prepareKeybindings(resolved, lua: lua)
        install(prepared, preferredLayer: keys.currentLayer)
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
            snapshot.layers,
            lua: lua
        )
        guard prepared.failures.isEmpty else {
            prepared.release(using: lua)
            return .failure(.preparationFailed)
        }
        install(
            prepared,
            preferredLayer: snapshot.activeLayer
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

    private func activeProfileLayersForLiveApply()
        -> Result<KeyLayerOverride?, LiveKeybindingApplyError>
    {
        guard let name = profiles.currentName else {
            return .success(nil)
        }
        do {
            return .success(try profiles.read(name: name).layers)
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
        in layers: [KeyLayer]
    ) -> KeyBinding? {
        layers.first(where: { $0.name == target.layer })?
            .bindings.last(where: {
                KeyCombo.equivalent(
                    $0.combo,
                    target.binding.combo
                )
            })
    }
}
