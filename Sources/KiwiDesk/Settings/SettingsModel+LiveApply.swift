import Foundation
import KiwiDeskCore

enum LiveApplyStatus: Equatable {
    case applied
    case inactiveLayer(String)
    case denied
    case profileShadowed
    case compileFailed
    case unavailable
}

/// Identity-carrying wrapper so re-recording the same row
/// restarts the transient caption timer.
struct LiveApplyFeedback: Equatable {
    let status: LiveApplyStatus
    let id = UUID()
}

/// Recorder-only runtime state. `modes` starts at the clean
/// Settings baseline and receives combo mutations only; staged
/// Lua/app/mode edits therefore cannot hitchhike live. The
/// snapshot is the disk-independent Revert fallback.
struct RecorderLiveSession {
    var layers: [KeyLayer]
    let snapshot: LiveKeybindingSnapshot
}

extension SettingsModel {
    /// Suspends/restores the live hotkeys while a recorder is
    /// armed (#213), so pressing an existing shortcut to test it
    /// mid-capture can't fire its action. Independent of the edit
    /// target: the running hotkeys are the live ones either way.
    func setRecorderArmed(_ armed: Bool) {
        if armed {
            core.suspendHotkeysForRecording()
        } else {
            core.resumeHotkeysForRecording()
        }
    }

    /// Applies one recorder combo mutation on the live target.
    /// Existing rows keep their clean runtime action even when
    /// their Lua/app fields have unrelated staged edits. A row
    /// newly created for this recording carries its current
    /// action because no earlier runnable action exists.
    func liveApplyRecorded(
        layerName: String,
        bindingID: UUID,
        combo: String?
    ) -> LiveApplyFeedback? {
        guard target == .live else { return nil }

        var session: RecorderLiveSession
        if let existing = liveKeySession {
            session = existing
        } else {
            guard let snapshot = core.liveKeybindingSnapshot()
            else {
                return feedback(
                    for: combo,
                    status: .unavailable
                )
            }
            session = RecorderLiveSession(
                layers: cleanConfig.layers,
                snapshot: snapshot
            )
        }

        let target = applyRecorderMutation(
            layerName: layerName,
            bindingID: bindingID,
            combo: combo,
            to: &session.layers
        )
        if combo != nil, target == nil {
            return feedback(for: combo, status: .unavailable)
        }

        switch core.liveApplyKeybindings(
            layers: session.layers,
            target: target
        ) {
        case .success(let status):
            if status != .compileFailed {
                liveKeySession = session
            }
            return feedback(
                for: combo,
                status: map(status)
            )
        case .failure:
            if combo == nil {
                profileWarning = L(
                    "key_recorder.live_apply_failed",
                    "The shortcut change was recorded but "
                        + "couldn't be applied live. Save or "
                        + "Revert to retry."
                )
            }
            return feedback(
                for: combo,
                status: .unavailable
            )
        }
    }

    /// Runs before `reload()` reads model state. Persisted state
    /// wins after Save; if disk/profile state is unreadable, the
    /// captured in-memory snapshot removes ghost hotkeys. Session
    /// bookkeeping clears only after one rollback path succeeds.
    func restoreLiveKeySessionIfNeeded() {
        guard let session = liveKeySession else { return }
        if case .success = core.restoreSavedLiveKeybindings() {
            liveKeySession = nil
            return
        }
        switch core.restoreLiveKeybindings(session.snapshot) {
        case .success:
            liveKeySession = nil
            profileWarning = L(
                "key_recorder.revert_used_snapshot",
                "Saved shortcuts couldn't be read, so Revert "
                    + "restored the previous running shortcuts."
            )
        case .failure(.superseded):
            // A newer load already replaced the VM/hotkeys;
            // its ownership is authoritative. Retire the stale
            // recorder session without replaying old callbacks.
            liveKeySession = nil
        case .failure:
            profileWarning = L(
                "key_recorder.revert_failed",
                "Revert couldn't restore the running shortcuts. "
                    + "Fix the configuration, then try again."
            )
        }
    }

    private func applyRecorderMutation(
        layerName: String,
        bindingID: UUID,
        combo: String?,
        to modes: inout [KeyLayer]
    ) -> LiveKeybindingTarget? {
        // Existing row: find by transient edit-session id across
        // every mode. A staged mode rename stays staged; runtime
        // ownership remains with the row's clean mode.
        for modeIndex in modes.indices {
            guard
                let bindingIndex = modes[modeIndex].bindings
                    .firstIndex(where: { $0.id == bindingID })
            else { continue }
            updateCombo(
                combo,
                bindingIndex: bindingIndex,
                modeIndex: modeIndex,
                modes: &modes
            )
            guard combo != nil else { return nil }
            return LiveKeybindingTarget(
                layer: modes[modeIndex].name,
                binding: modes[modeIndex].bindings[
                    bindingIndex
                ]
            )
        }

        // New row: its action is required payload for its first
        // recording. Later non-recorder edits stay staged because
        // subsequent recordings find this session copy by id.
        guard let combo,
            let editedMode = config.layers.first(where: {
                $0.name == layerName
            }),
            var binding = editedMode.bindings.first(where: {
                $0.id == bindingID
            })
        else { return nil }
        binding.combo = combo
        let modeIndex: Int
        if let existing = modes.firstIndex(where: {
            $0.name == layerName
        }) {
            modeIndex = existing
        } else {
            modes.append(KeyLayer(name: layerName))
            modeIndex = modes.index(before: modes.endIndex)
        }
        clearCombo(
            combo,
            except: bindingID,
            in: &modes[modeIndex].bindings
        )
        modes[modeIndex].bindings.append(binding)
        return LiveKeybindingTarget(
            layer: modes[modeIndex].name,
            binding: binding
        )
    }

    private func updateCombo(
        _ combo: String?,
        bindingIndex: Int,
        modeIndex: Int,
        modes: inout [KeyLayer]
    ) {
        if let combo {
            let id = modes[modeIndex].bindings[bindingIndex].id
            clearCombo(
                combo,
                except: id,
                in: &modes[modeIndex].bindings
            )
        }
        modes[modeIndex].bindings[bindingIndex].combo = combo ?? ""
    }

    private func clearCombo(
        _ combo: String,
        except id: UUID,
        in bindings: inout [KeyBinding]
    ) {
        for index in bindings.indices
        where bindings[index].id != id
            && KeyCombo.equivalent(
                bindings[index].combo,
                combo
            )
        {
            bindings[index].combo = ""
        }
    }

    private func map(
        _ status: LiveKeybindingApplyStatus?
    ) -> LiveApplyStatus? {
        switch status {
        case .active: .applied
        case .inactiveLayer(let name): .inactiveLayer(name)
        case .denied: .denied
        case .profileShadowed: .profileShadowed
        case .compileFailed: .compileFailed
        case nil: nil
        }
    }

    private func feedback(
        for combo: String?,
        status: LiveApplyStatus?
    ) -> LiveApplyFeedback? {
        guard combo != nil, let status else { return nil }
        return LiveApplyFeedback(status: status)
    }
}
