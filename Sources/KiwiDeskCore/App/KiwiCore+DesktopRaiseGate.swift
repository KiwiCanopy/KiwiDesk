import Foundation

/// The Desktop raise gate (#1345/#1410): raising a window the
/// compositor is not showing makes macOS switch Desktops to show
/// it, so no implicit raise may do that; a verb that means to
/// switch takes `switchDesktop`. Two compositor reads, never
/// state; the argument is state-and-layout.md's.
extension KiwiCore {
    /// Whether raising `id` would switch Desktops: either read
    /// says the compositor is not showing it. A read that cannot
    /// answer (nil) abstains; both abstaining keeps the raise. A
    /// close in flight reads not drawn and is refused too — that
    /// raise was a no-op — so the consumers' log names both.
    func raiseCrossesDesktops(_ id: WindowID) -> Bool {
        if windowIsOnScreen(id) == false { return true }
        guard windowIsOnShownDesktop(id) == false else { return false }
        onLog(
            "raise gate: w\(id.raw) is drawn but hosted on a Desktop "
                + "no display shows — a gesture's composite, "
                + "refused (#1410)"
        )
        return true
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
