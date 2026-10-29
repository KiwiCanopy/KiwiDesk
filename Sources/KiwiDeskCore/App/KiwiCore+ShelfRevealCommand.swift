import AppKit

/// A bar's show/hide verb (#761): shows or hides the bar on the
/// active Space's screen, and refuses with a pill where it cannot
/// (#2567).
extension KiwiCore {
    /// `space_bar.toggle_reveal` / `app_bar.toggle_reveal` (#761):
    /// shows or hides the bar on the screen the active Space lays
    /// out on, over the windows, and only that bar. A shelf stood
    /// down for what is in front is refused first (#2775); a bar set
    /// to `always` is refused with a pill on the bar, since it is
    /// already shown; the App Bar is refused where the active
    /// Space's layout carries none.
    func shelfRevealCommand(_ bar: ShelfBar) -> CommandResponse {
        let name = bar == .space ? "Space Bar" : "App Bar"
        let workspaces = state.workspaces
        guard let space = workspaces.activeSpace,
            let display = workspaces.display(of: space)
        else { return .fail("the \(name) draws on no screen here") }
        // Asked before the layout and the setting: a window filling
        // the screen is why nothing shows, whatever those say (#2775).
        if shelfStandsDown(on: display) {
            cueRevealRefusal(.standsDown(bar), display: display)
            return .fail("the \(name) stands down for what is in front")
        }
        let mode = workspaces[space]?.mode ?? .bsp
        let settings = tiler.settings
        guard bar == .space || settings.appBarVisibility(in: mode) != nil
        else {
            cueRevealRefusal(.noAppBarHere, display: display)
            return .fail("no App Bar in this layout")
        }
        guard settings.revealActionLive(bar, in: mode) else {
            cueRevealRefusal(.alwaysShown(bar), display: display)
            return .fail("the \(name) is set to always")
        }
        // The edge's own fold answers whether the bar hides here: an
        // `auto` bar beside an `always` one reads `always` (#761).
        if settings.autoReadsAlways(
            bar,
            in: mode,
            on: screenFingerprint(of: display)
        ) {
            cueRevealRefusal(.shownBesideAlways(bar), display: display)
            return .fail("the \(name) is shown beside an always bar")
        }
        guard
            let key = shelves.reveal.targets.keys.first(where: {
                $0.shelf.display == display && $0.bar == bar
            })
        else {
            if let refusal = emptyRefusal(bar, on: display) {
                cueRevealRefusal(refusal, display: display)
            }
            return .fail("the \(name) has nothing to show here")
        }
        guard toggleBarReveal(key) else {
            return .fail("the \(name) is held shown by the tour")
        }
        return .ok()
    }

    /// The pill a show/hide with no reveal target owes: nothing to
    /// show where the bar's own content is empty (#2567), and the
    /// stand-down's where the shelf stands down for what is in
    /// front, which is no empty bar (#2775).
    func emptyRefusal(
        _ bar: ShelfBar,
        on display: DisplayID
    ) -> RevealRefusal? {
        guard !shelfStandsDown(on: display) else {
            return .standsDown(bar)
        }
        let settings = tiler.settings
        let empty =
            bar == .app
            ? appBarContent(on: display, settings: settings) == nil
            : spaceBarContent(on: display, style: settings.spaceBarLook)
                == nil
        return empty ? .nothingToShow(bar) : nil
    }
}
