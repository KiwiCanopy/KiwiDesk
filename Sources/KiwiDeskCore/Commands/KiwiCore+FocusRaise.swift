import AppKit
import Foundation

/// The deferred scrolling focus raise (#143).
///
/// In scrolling mode a focus move pans the viewport. Raising
/// the target first is jarring when focusing *up*: the row
/// above sits pinned at the top border BEHIND the current
/// window (#66/#139), and an immediate raise pops it over the
/// whole screen before the slide starts. Deferred, the current
/// window slides away and gradually reveals the pinned row;
/// front and keyboard focus land when the pan does.
///
/// Timing rides the same settle signal as the z-order restore
/// (`AnimationEngine.onAllAnimationsEnded` — the shared slot in
/// `KiwiCore.init` runs both). Known trade, documented in the
/// Lua reference and accepted limitations: keystrokes during
/// the slide (one animation length, 50–1000 ms) still reach
/// the previously focused app; Carbon hotkeys are unaffected.
extension KiwiCore {
    /// The one `onAllAnimationsEnded` consumer — the slot is a
    /// single callback by design; this method IS the dispatch.
    /// Two pending-flag clients today, order-insensitive (the
    /// z-order restore's async pile raises end by re-asserting
    /// the focused window on top, healing any interleaving
    /// with the synchronous focus raise). Fork this into a
    /// real dispatcher only when (a) a third pending consumer
    /// appears, (b) ordering between the runners becomes
    /// semantic, or (c) a client needs per-monitor/per-space
    /// settle instead of the global count-zero signal.
    func animationsDidSettle() {
        runPendingZOrderRestore()
        runPendingFocusRaise()
    }

    /// Fires a pending deferred raise. Called when animations
    /// settle, and directly by `focusWindow` when no animation
    /// started. Re-validates at fire time: a newer focus
    /// command, a real focus echo (user click mid-pan), or a
    /// destroyed target have superseded the raise — drop it
    /// silently rather than steal focus back.
    func runPendingFocusRaise() {
        guard let id = pendingFocusRaise else { return }
        pendingFocusRaise = nil
        guard id == activeSpace?.focused else { return }
        raiseWindow(id)
    }

    /// The one AX raise call behind both the immediate and the
    /// deferred focus paths.
    func raiseWindow(_ id: WindowID) {
        if let window = state.windows[id],
            let element = eventLoop.element(for: id)
        {
            AXHelper.raise(element, pid: window.pid)
        }
    }
}
