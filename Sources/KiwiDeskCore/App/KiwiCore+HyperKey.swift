import Foundation

/// The Hyper key (#1870): the source key KiwiDesk remaps to F18
/// and the layer `KeybindingManager+Hyper` registers while it is
/// held. The chosen key is `appWide.hyperKey` alone; the remap is
/// KiwiCore's — the manager never spawns `hidutil` — and it lives
/// only while KiwiDesk manages windows: `start()` applies it,
/// `stop()` gives the key back.
extension KiwiCore {
    /// `set_hyper_key <key|off>`: the running value, as every
    /// app-wide verb (#1741); the Settings row stores it
    /// (`hyper.key`). Applied at once, so the reply says whether
    /// the key took.
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
        setAppWide(persisting: false) { $0.hyperKey = want }
        // The same key again is a retry too: a refused remap may
        // have gone since.
        if eventLoop.isRunning {
            deferred.cancel(.hyperRemap)
            applyHyperKey()
        }
        switch keys.hyperStatus {
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

    /// A changed key from any door — a row, a verb, a reload, a
    /// restore — remaps once, after the change settles, and only
    /// while KiwiDesk manages windows: a reload that resets the
    /// value and has `init.lua` set it again remaps once.
    func oweHyperRemap() {
        guard eventLoop.isRunning else { return }
        deferred.schedule(.hyperRemap, after: .zero) { [weak self] in
            self?.applyHyperKey()
        }
    }

    /// Brings the remap and the layer in line with
    /// `appWide.hyperKey`: at `start()`, which also clears a
    /// mapping a crash left behind, and for a change while running.
    @discardableResult
    func applyHyperKey() -> HyperKeyStatus {
        let want = appWide.hyperKey
        // Nothing chosen and nothing of ours to clear: no spawn.
        if want == nil, hyperRemapHost.readWritten() == nil {
            setHyperState(.off)
            return .off
        }
        let outcome = HyperKeyRemap.apply(want, on: hyperRemapHost)
        // Off asked is off had: a mapping KiwiDesk cannot touch
        // is not the user's Hyper key.
        let status = want == nil ? .off : outcome
        setHyperState(status)
        if want != nil, outcome == .refused || outcome == .failed {
            onLog("hyper: remap \(outcome), Hyper key off")
        }
        return status
    }

    /// Gives the key back at `stop()`; the choice is kept, so the
    /// next `start()` remaps it again.
    func retireHyperKey() {
        deferred.cancel(.hyperRemap)
        setHyperState(.off)
        // What was applied, never the wanted key: an off still
        // owed when the stop cancelled it left the mapping ours.
        guard hyperRemapHost.readWritten() != nil else { return }
        _ = HyperKeyRemap.apply(nil, on: hyperRemapHost)
    }

    /// The layer and the status the row reads move together, and a
    /// status the ledger did not move still reaches Settings.
    private func setHyperState(_ status: HyperKeyStatus) {
        let changed = keys.hyperStatus != status
        keys.hyperStatus = status
        keys.hyperEnabled = status == .on
        if changed { onAppWideChange() }
    }
}
