import Foundation

/// The Desktop raise gate (#1345): raising a window the
/// compositor is not drawing makes macOS switch Desktops to show
/// it, so no implicit raise may do that; a verb that means to
/// switch takes `switchDesktop`. The read is CGWindowList's own
/// on-screen flag, the compositor's ground truth — never state,
/// which still holds a departed window behind a slow app's
/// destroy, and never the managed display's "current Space",
/// which lags the draw list through a switch (#1023). The
/// argument is state-and-layout.md's.
extension KiwiCore {
    /// Whether raising `id` would switch Desktops: the compositor
    /// is not drawing it. A close in flight reads the same and is
    /// refused too — that raise was a no-op — so the log names
    /// both; nil (never listed, or no read) keeps the raise.
    func raiseCrossesDesktops(_ id: WindowID) -> Bool {
        windowIsOnScreen(id) == false
    }

    /// The distrust arms' shared stand-down: a re-assert of
    /// `intended` against a report for `id` is refused, and the
    /// report honored instead, when the re-assert would switch
    /// Desktops. A nil or self-intended re-assert raises nothing
    /// and is never refused.
    func reassertCrossesDesktops(
        _ intended: WindowID?,
        against id: WindowID
    ) -> Bool {
        guard let intended, intended != id,
            raiseCrossesDesktops(intended)
        else { return false }
        onLog(
            "focus: re-assert of w\(intended.raw) refused — "
                + "not on screen (closed, or a Desktop nobody shows); "
                + "honoring w\(id.raw) (#1345)"
        )
        return true
    }
}
