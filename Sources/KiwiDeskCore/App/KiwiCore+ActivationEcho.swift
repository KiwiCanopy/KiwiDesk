import AppKit
import Foundation

/// The sibling ACTIVATION echo of our own z-order raise
/// (#1049), split from `KiwiCore+FocusEvents.swift` (350-line
/// ceiling); `handleWindowFocused` is the one caller.
extension KiwiCore {
    /// Consumes a focus report that is the app ACTIVATING
    /// itself in answer to our raise of one of its OTHER
    /// windows. AX couples a raise with app activation, and the
    /// per-window net (`zOrderRaiseEchoes[id]`) absorbs the
    /// raised window's own echo — but a Qt-class app (the
    /// Android emulator) answers the activation by keying its
    /// MAIN window, which the raise never stamped, so the steal
    /// was honored: pointer warped onto the emulator, the
    /// restore re-asserted the real focus, the float raise
    /// fired again on that change, and the app stole again —
    /// a closed ~2 s loop with no user input (#1049 log
    /// capture, 2026-08-27).
    ///
    /// The discriminators, each load-bearing:
    /// - the provocation evidence, either of two: a fresh stamp
    ///   on a SAME-PID sibling (our raise provoked this —
    ///   without one, an app keying its own window is the
    ///   user's business), or OUR OWN recent frame-set on the
    ///   reported window itself while it carries a learned
    ///   size bound — a known size-fighter (the emulator)
    ///   also activates itself in answer to a resize, which
    ///   is how the flap re-add's placement stole focus with
    ///   no raise anywhere (#1049 QA round 2). The bound term
    ///   keeps that arm off ordinary windows: after any big
    ///   retile many windows sit inside their set grace, and
    ///   a cmd-tab onto one must stay honored;
    /// - `intended` in ANOTHER app: the steal yanks focus
    ///   cross-app, while an in-app report within the stamp
    ///   window is the user cycling windows (cmd-`) — a float
    ///   raise follows every focus change, so an in-app arm
    ///   would eat the second press of every quick cycle in
    ///   any app that owns a float;
    /// - no click provenance (#687) and no fresh self-raise
    ///   (#431): both are proof of intent no echo can forge.
    /// A clickless cross-app focus of the sibling (cmd-tab)
    /// inside the ~1 s stamp window is eaten once — the same
    /// accepted trade the #465 sibling distrust documents.
    ///
    /// The re-assert goes through `raiseWindow`, which STAMPS
    /// the raise — so the re-assert's own focus echo classifies
    /// as a self-echo and the caller's float re-raise stands
    /// down, which is what terminates the loop. An unstamped
    /// re-assert (the #465 branch's choice) would echo as a
    /// genuine focus change, re-raise the floats, and provoke
    /// the very steal it just reverted.
    func consumeSiblingActivationEcho(
        _ id: WindowID,
        before intended: WindowID?,
        now: Date
    ) -> Bool {
        guard zOrderRaiseEchoes[id] == nil,
            let pid = state.windows[id]?.pid,
            let intended, intended != id,
            let intendedWindow = state.windows[intended],
            intendedWindow.pid != pid,
            let space = state.workspaces.space(of: intended),
            !freshSelfRaise(id, now: now),
            !recentClickReached(id, now: now)
        else { return false }
        let siblingRaised = zOrderRaiseEchoes.contains {
            entry in
            entry.key != id
                && now.timeIntervalSince(entry.value)
                    < Self.zOrderRaiseEchoWindow
                && state.windows[entry.key]?.pid == pid
        }
        let resizeProvoked =
            tiler.askEchoLikely(id)
            && tiler.sizeBound(for: id) != nil
        guard siblingRaised || resizeProvoked
        else { return false }
        onLog(
            "focus: w\(id.raw) sibling activation echo "
                + "reverted to w\(intended.raw)"
        )
        state.workspaces.focus(intended, in: space)
        raiseWindow(intended)
        updateBorders()
        updateStickyMarks()
        return true
    }
}
