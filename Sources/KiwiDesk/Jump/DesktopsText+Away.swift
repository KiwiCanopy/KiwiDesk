import KiwiDeskCore

/// Core's reasons a window on a hidden Desktop did not move (#3171),
/// in the panel's words: each states the rule that forbids the act
/// (core-boundaries.md ▸ #3033).
extension DesktopsText {
    static func awayRefusal(_ reason: AwayMoveRefusal) -> String {
        switch reason {
        case .pocketed:
            L(
                "desktop_overview.refusal.pocketed",
                "Pocketed windows can’t change Desktop"
            )
        case .pocketWindow:
            L(
                "desktop_overview.refusal.pocket_window",
                "Pocket windows can’t change Desktop"
            )
        case .fullScreen:
            L(
                "desktop_overview.refusal.full_screen_move",
                "Full-screen windows can’t change Desktop"
            )
        case .followHidden:
            L(
                "desktop_overview.refusal.follow_hidden",
                "Can’t follow a minimized or hidden window"
            )
        case .sticky:
            L(
                "desktop_overview.refusal.sticky",
                "Sticky windows keep their Space"
            )
        case .stillLanding:
            L(
                "desktop_overview.refusal.still_landing",
                "A window moves again once its last move lands"
            )
        case .unreachable:
            refusal(DesktopsRefusal.unreachable)
        case .noDesktopBridge:
            L(
                "desktop_overview.refusal.no_bridge",
                "This macOS can’t move windows between Desktops"
            )
        }
    }
}
