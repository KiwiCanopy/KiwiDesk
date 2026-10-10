import Foundation

/// What a Desktop switch's re-sync owes once it ends: one pass
/// for every event retile it folded, and the track restore the
/// close-return tail would have armed after each.
struct SwitchResyncBatch {
    var owesRetile = false
    var armsTrackRestore = false
}

/// The Desktop switch's bulk re-sync as ONE pass. Leaving a
/// Desktop folds each of its windows as a departure and each was a
/// full retile, bars and rings included — 17 passes for one
/// switch on the device, all inside the switch's main turn, so the
/// ring stood on the departed window until they ended.
extension KiwiCore {
    /// Runs `body` with every structural event retile folded into
    /// one pass at its end. The restore a fold would arm is armed
    /// after that pass, never before it (#153).
    func foldingSwitchResync(_ body: () -> Void) {
        guard switchResync == nil else { return body() }
        switchResync = SwitchResyncBatch()
        body()
        let batch = switchResync
        switchResync = nil
        guard let batch, batch.owesRetile else { return }
        // A switch reveals windows; nothing to fly (see
        // `handleDesktopChange`).
        retile(animated: false, pass: .event)
        if batch.armsTrackRestore {
            scheduleTrackZOrderRestoreIfOverflowing()
        }
    }

    /// Folds an event retile into the running re-sync, if one
    /// runs; false asks the caller to retile now.
    func foldIntoSwitchResync() -> Bool {
        guard switchResync != nil else { return false }
        switchResync?.owesRetile = true
        return true
    }
}
