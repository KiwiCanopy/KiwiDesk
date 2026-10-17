import Foundation

/// The float-tier raise owed while the tiled plane still moves
/// (#2284): a pan, an owed #804 pass, or a z-order restore armed or
/// draining lands tiles over floats raised ahead of it, so the
/// raise waits and is paid when the plane comes to rest.
@MainActor
final class FloatRaiseDebt {
    /// The focus the owed raise keeps floats above; one slot, so
    /// only the last focus raises.
    var owed: WindowID?
    /// Tiled z-order restores draining — never the float raise's
    /// own, which a newer focus must still supersede at once.
    var restoresInFlight = 0
}

extension KiwiCore {
    /// Whether a float raise issued now would land under tiles
    /// still moving: the one predicate the wait asks.
    var tiledPlaneMoving: Bool {
        tiler.animation.activeCount > 0
            || tiler.motionGate.owed != nil
            || pendingZOrderRestore
            || floatRaiseDebt.restoresInFlight > 0
    }

    /// What the tiled plane coming to rest pays (#2284, #2343): the
    /// z-order restore that waited for it and the deferred focus
    /// raise where the caller says they run, then the owed float
    /// raise, last so the floats land above both. Every rest site
    /// takes this door, never a payer beside it.
    func tiledPlaneCameToRest(restore: Bool, focusRaise: Bool) {
        if restore { runPendingZOrderRestore() }
        if focusRaise { runPendingFocusRaise() }
        runPendingFloatRaise()
    }

    /// Pays the owed raise; the raise re-asks the predicate, so a
    /// restore this settle just started owes it again, to its own
    /// completion. A debt for a focus that has moved on is dropped:
    /// paying it would replace the newer focus's scheduled raise.
    func runPendingFloatRaise() {
        guard let id = floatRaiseDebt.owed else { return }
        floatRaiseDebt.owed = nil
        guard id == focusedWindowID else { return }
        raiseFloatsAbove(afterFocusing: id)
    }
}
