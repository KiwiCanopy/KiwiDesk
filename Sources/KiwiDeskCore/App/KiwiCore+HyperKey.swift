import Foundation

/// The Hyper key (#1870): the source key KiwiDesk remaps to F18
/// and the layer `KeybindingManager+Hyper` registers while it is
/// held. The remap is KiwiCore's — the manager never spawns
/// `hidutil` — and it lives only while KiwiDesk runs.
extension KiwiCore {
    /// `set_hyper_key <key|off>`. Session only for now: #1870's
    /// stored setting is the Settings row's.
    func setHyperKey(_ args: [JSONValue]) -> CommandResponse {
        guard let name = args.first?.stringValue else {
            return .fail("expected a key name or off")
        }
        let want: HyperSourceKey?
        if name == "off" {
            want = nil
        } else if let key = HyperSourceKey(rawValue: name) {
            want = key
        } else {
            return .fail("expected off|\(HyperSourceKey.expectedList)")
        }
        keys.hyperSource = want
        switch applyHyperKey() {
        case .refused:
            return .fail(
                "a key remap KiwiDesk did not set is in place; "
                    + "Hyper stays off"
            )
        case .failed:
            return .fail("hidutil did not answer; Hyper stays off")
        case .on, .off:
            return .ok()
        }
    }

    /// Brings the remap and the layer in line with
    /// `keys.hyperSource`: at `start()`, which also clears a
    /// mapping a crash left behind, and on the verb.
    @discardableResult
    func applyHyperKey() -> HyperKeyStatus {
        // Nothing chosen and nothing of ours to clear: no spawn.
        if keys.hyperSource == nil, hyperRemapHost.readWritten() == nil {
            keys.hyperStatus = .off
            keys.hyperEnabled = false
            return .off
        }
        let outcome = HyperKeyRemap.apply(
            keys.hyperSource,
            on: hyperRemapHost
        )
        // Off asked is off had: a mapping KiwiDesk cannot touch
        // is not the user's Hyper key.
        let status = keys.hyperSource == nil ? .off : outcome
        keys.hyperStatus = status
        keys.hyperEnabled = status == .on
        if keys.hyperSource != nil,
            outcome == .refused || outcome == .failed
        {
            onLog("hyper: remap \(outcome), Hyper key off")
        }
        return status
    }

    /// Gives the key back at `stop()`; the choice is kept, so the
    /// next `start()` remaps it again.
    func retireHyperKey() {
        keys.hyperEnabled = false
        keys.hyperStatus = .off
        guard keys.hyperSource != nil else { return }
        _ = HyperKeyRemap.apply(nil, on: hyperRemapHost)
    }
}
