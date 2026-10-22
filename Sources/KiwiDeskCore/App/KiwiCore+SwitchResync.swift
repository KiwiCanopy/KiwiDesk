import Foundation

/// What a Desktop switch's re-sync owes once it ends: one pass
/// for the event retiles it folded, then the work that must follow
/// that pass, in the order it was owed.
struct SwitchResyncBatch {
    var owesRetile = false
    /// A folded removal's retile: the pass holds the run arm for
    /// the close-return tail (#936, #2235).
    var holdsRunArm = false
    /// A folded event whose close-return verdict lets the arm
    /// through: the held pass's run debt is paid.
    var runArmPays = false
    var afterPass: [@MainActor () -> Void] = []
}

/// The Desktop switch's bulk re-sync as ONE pass: the generic
/// structural retile in `handle(_:)` is owed rather than run for
/// each window the re-sync adds or removes. A retile an arm runs
/// itself (a float flip, a follow) is not folded.
extension KiwiCore {
    /// Runs `body`, then one switch pass if any event retile was
    /// owed, then the owed after-pass work — the close-return
    /// raise and the z-order arms, which go after the pass that
    /// places the row (#153). The pass is the switch's own, so
    /// the motion gate never holds it (#804) and it snaps like
    /// `handleDesktopChange`'s.
    func foldingSwitchResync(_ body: () -> Void) {
        guard switchResync == nil else { return body() }
        switchResync = SwitchResyncBatch()
        body()
        let batch = switchResync ?? SwitchResyncBatch()
        switchResync = nil
        var runArmOwed = false
        if batch.owesRetile {
            tiler.motionGate.exemptingSwitch {
                runArmOwed = holdingRunArm(batch.holdsRunArm) {
                    retile(animated: false, pass: .event)
                }
            }
        }
        for work in batch.afterPass { work() }
        if runArmOwed, batch.runArmPays { scheduleZOrderRestore() }
    }

    /// The close-return tail's verdict for the run arm, inside a
    /// re-sync: the held pass's debt is paid (#936, #2235).
    func voteRunArmPays() {
        switchResync?.runArmPays = true
    }

    /// Folds an event retile into the running re-sync, if one
    /// runs; false asks the caller to retile now. A removal's
    /// fold holds the pass's run arm.
    func foldIntoSwitchResync(removal: Bool) -> Bool {
        guard switchResync != nil else { return false }
        switchResync?.owesRetile = true
        if removal { switchResync?.holdsRunArm = true }
        return true
    }

    /// Runs `work` now, or after the running re-sync's pass.
    func afterSwitchResync(_ work: @escaping @MainActor () -> Void) {
        if switchResync != nil {
            switchResync?.afterPass.append(work)
        } else {
            work()
        }
    }
}
