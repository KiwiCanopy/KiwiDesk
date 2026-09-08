import Foundation

/// The Desktop raise gate (#1345): raising a window the
/// compositor hosts on a Desktop no display shows IS a Desktop
/// switch — macOS switches to show what was raised — so no
/// implicit raise may perform one; a verb that means to switch
/// takes `switchDesktop`. Read from the compositor, never from
/// state: the window that bounced the device was still IN state,
/// its app's destroy notification seconds behind the swipe. The
/// argument is state-and-layout.md's.
extension KiwiCore {
    /// Whether raising `id` would switch Desktops: hosted on a
    /// Space no display shows. Unknown (no SkyLight), gone and
    /// shown all answer false — the raise is then harmless or
    /// wanted. One topology reading per ask (profiles.md).
    func raiseCrossesDesktops(_ id: WindowID) -> Bool {
        if case .hosted(_, shown: false) = gonePresence(
            of: id,
            spaces: NativeSpaces.allSpaces()
        ) {
            return true
        }
        return false
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
                + "hosted on a Desktop nobody shows; honoring "
                + "w\(id.raw) (#1345)"
        )
        return true
    }
}
