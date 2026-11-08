import KiwiDeskCore

/// The Desktops side's words (#1229): its hints, its refusals and
/// what VoiceOver hears. Core names; this narrates (#96).
@MainActor
enum DesktopsText {
    static var empty: String { L("desktop_overview.line.empty", "Empty") }

    static var unfiled: String {
        L("desktop_overview.line.unfiled", "Not in a Space yet")
    }

    static var shown: String { L("desktop_overview.card.shown", "shown") }

    static var main: String { L("desktop_overview.screen.main", "main") }
    static var here: String { L("desktop_overview.screen.here", "here") }

    static func desktop(_ number: Int) -> String {
        L("desktop_overview.card.title", "Desktop %1$d", number)
    }

    static func space(_ id: SpaceID) -> String {
        L("desktop_overview.line.space", "Space %1$@", id.raw)
    }

    /// The footer's tray while windows ride along.
    static func moving(_ count: Int) -> String {
        count == 1
            ? L("desktop_overview.tray.one", "Moving 1 window")
            : L("desktop_overview.tray.other", "Moving %1$d windows", count)
    }

    // MARK: Hints

    static var jump: String {
        L("desktop_overview.footer.jump", "%1$@ Jump", "↩")
    }

    static var moveThere: String {
        L(
            "desktop_overview.footer.move_there",
            "%1$@ Move window there",
            "⇧↩"
        )
    }

    static var moveFollow: String {
        L(
            "desktop_overview.footer.move_follow",
            "%1$@ Move & follow",
            "⌃↩"
        )
    }

    static var moveHere: String {
        L("desktop_overview.footer.move_here", "%1$@ Move here", "⇧↩")
    }

    static var swapHere: String {
        L("desktop_overview.footer.swap_here", "%1$@ Swap here", "⌥↩")
    }

    static var openSpace: String {
        L("desktop_overview.footer.open_space", "%1$@ Open Space", "⌘↓")
    }

    static var back: String {
        L("desktop_overview.footer.back", "%1$@ Back", "⌘↑")
    }

    static var pickUp: String {
        L("desktop_overview.footer.pick_up", "%1$@ Pick up", "⌘↩")
    }

    static var putBack: String {
        L("desktop_overview.footer.put_back", "%1$@ Put back", "⌘↩")
    }

    static var drop: String {
        L("desktop_overview.footer.drop", "%1$@ Drop", "↩")
    }

    static var dropFollow: String {
        L(
            "desktop_overview.footer.drop_follow",
            "%1$@ Drop & follow",
            "⌃↩"
        )
    }

    static var cancel: String {
        L("desktop_overview.footer.cancel", "%1$@ Cancel", "Esc")
    }

    static func jumpDesktop(_ digits: String) -> String {
        L(
            "desktop_overview.footer.jump_desktop",
            "%1$@ Jump to Desktop",
            digits
        )
    }

    static func moveDesktop(_ digits: String) -> String {
        L(
            "desktop_overview.footer.move_desktop",
            "%1$@ Move to Desktop",
            digits
        )
    }

    static func dropDesktop(_ digits: String) -> String {
        L(
            "desktop_overview.footer.drop_desktop",
            "%1$@ Drop on Desktop",
            digits
        )
    }

    // MARK: Refusals

    static func refusal(_ refusal: DesktopsRefusal) -> String {
        switch refusal {
        case .carryBlocked(let window, let block):
            let name = window.title.isEmpty ? window.app : window.title
            switch block {
            case .otherDesktop:
                return L(
                    "desktop_overview.refusal.other_desktop",
                    "“%1$@” is on another Desktop and can’t be "
                        + "picked up",
                    name
                )
            case .pocketed:
                return L(
                    "desktop_overview.refusal.pocketed",
                    "“%1$@” is in your Pocket and can’t be picked up",
                    name
                )
            case .fullScreen:
                return L(
                    "desktop_overview.refusal.full_screen",
                    "“%1$@” is in full screen and can’t be picked up",
                    name
                )
            }
        case .emptySpace:
            return L(
                "desktop_overview.refusal.empty",
                "This Space has no windows"
            )
        case .noSpace:
            return L(
                "desktop_overview.refusal.no_space",
                "Windows can only move into a Space"
            )
        case .nothingYours:
            return L(
                "desktop_overview.refusal.nothing_yours",
                "There is no window of yours to move"
            )
        case .alreadyThere(let space):
            return L(
                "desktop_overview.refusal.already_there",
                "The picked windows are already in Space %1$@",
                space.raw
            )
        }
    }

    /// A window that did not move at a drop.
    static func notMoved(_ window: DesktopOverview.Window) -> String {
        let name = window.title.isEmpty ? window.app : window.title
        return L(
            "desktop_overview.refusal.not_moved",
            "“%1$@” did not move",
            name
        )
    }
}
