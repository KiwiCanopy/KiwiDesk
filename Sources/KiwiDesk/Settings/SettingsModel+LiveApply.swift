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

/// Transient feedback token for shortcut live apply HUD.
struct LiveApplyFeedback: Equatable {
    let status: LiveApplyStatus
    let id = UUID()
}

/// Runtime session tracking live recorded shortcut mutations.
struct RecorderLiveSession {
    var layers: [KeyLayer]
    let snapshot: LiveKeybindingSnapshot
}

extension SettingsModel {
    /// Suspends or resumes hotkeys while recording shortcut input (#213).
    func setRecorderArmed(_ armed: Bool) {
        if armed {
            core.suspendHotkeysForRecording()
        } else {
            core.resumeHotkeysForRecording()
        }
    }

    /// Applies recorded keybinding combo to live runtime session.
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
                        + "couldn't be applied live. %1$@ or "
                        + "%2$@ to retry.",
                    L("footer.save", "Save"),
                    L("footer.revert", "Revert")
                )
            }
            return feedback(
                for: combo,
                status: .unavailable
            )
        }
    }

    /// Restores saved keybinding state or rolls back to captured snapshot.
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
                "Saved shortcuts couldn't be read, so %1$@ "
                    + "restored the previous running shortcuts.",
                L("footer.revert", "Revert")
            )
        case .failure(.superseded):
            liveKeySession = nil
        case .failure:
            profileWarning = L(
                "key_recorder.revert_failed",
                "%1$@ couldn't restore the running shortcuts. "
                    + "Fix the configuration, then try again.",
                L("footer.revert", "Revert")
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
        for layerIndex in modes.indices {
            guard
                let bindingIndex = modes[layerIndex].bindings
                    .firstIndex(where: { $0.id == bindingID })
            else { continue }
            updateCombo(
                combo,
                bindingIndex: bindingIndex,
                layerIndex: layerIndex,
                modes: &modes
            )
            guard combo != nil else { return nil }
            return LiveKeybindingTarget(
                layer: modes[layerIndex].name,
                binding: modes[layerIndex].bindings[
                    bindingIndex
                ]
            )
        }

        // New row: its action is required payload for its first
        // recording. Later non-recorder edits stay staged because
        // subsequent recordings find this session copy by id.
        guard let combo,
            let editedLayer = config.layers.first(where: {
                $0.name == layerName
            }),
            var binding = editedLayer.bindings.first(where: {
                $0.id == bindingID
            })
        else { return nil }
        binding.combo = combo
        let layerIndex: Int
        if let existing = modes.firstIndex(where: {
            $0.name == layerName
        }) {
            layerIndex = existing
        } else {
            modes.append(KeyLayer(name: layerName))
            layerIndex = modes.index(before: modes.endIndex)
        }
        clearCombo(
            combo,
            except: bindingID,
            in: &modes[layerIndex].bindings
        )
        modes[layerIndex].bindings.append(binding)
        return LiveKeybindingTarget(
            layer: modes[layerIndex].name,
            binding: binding
        )
    }

    private func updateCombo(
        _ combo: String?,
        bindingIndex: Int,
        layerIndex: Int,
        modes: inout [KeyLayer]
    ) {
        if let combo {
            let id = modes[layerIndex].bindings[bindingIndex].id
            clearCombo(
                combo,
                except: id,
                in: &modes[layerIndex].bindings
            )
        }
        modes[layerIndex].bindings[bindingIndex].combo = combo ?? ""
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
