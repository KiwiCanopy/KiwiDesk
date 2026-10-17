import Foundation
import KiwiDeskCore

/// The folded rows' labels (#2312): each family's own key, the
/// range interpolated last so no locale must agree with it.
extension ShortcutFold {
    /// A folded ladder's label, its range interpolated last.
    @MainActor static func ladderLabel(
        _ family: Family,
        range: String
    ) -> String {
        switch family {
        case .goToSpace:
            return L(
                "shortcuts.fold.go_to_space",
                "Go to Space %1$@",
                range
            )
        case .moveToSpace:
            return L(
                "shortcuts.fold.move_to_space",
                "Move to Space %1$@",
                range
            )
        case .moveToSpaceFollow:
            return L(
                "shortcuts.fold.move_to_space_follow",
                "Move to Space & follow: %1$@",
                range
            )
        case .goToDesktop:
            return L(
                "shortcuts.fold.go_to_desktop",
                "Go to Desktop %1$@",
                range
            )
        case .moveToDesktop:
            return L(
                "shortcuts.fold.move_to_desktop",
                "Move to Desktop %1$@",
                range
            )
        case .moveToDesktopFollow:
            return L(
                "shortcuts.fold.move_to_desktop_follow",
                "Move to Desktop & follow: %1$@",
                range
            )
        default:
            return setLabel(family)
        }
    }

    /// A folded set's label, naming its members in their order.
    @MainActor static func setLabel(_ family: Family) -> String {
        switch family {
        case .focusDirections:
            return L(
                "shortcuts.fold.focus_directions",
                "Focus window left, down, up, right"
            )
        case .swapDirections:
            return L(
                "shortcuts.fold.swap_directions",
                "Swap with window left, down, up, right"
            )
        case .spaceStep:
            return L(
                "shortcuts.fold.space_step",
                "Go to previous / next Space"
            )
        case .spaceHistory:
            return L(
                "shortcuts.fold.space_history",
                "Go back / forward in Space history"
            )
        case .layoutCycle:
            return L(
                "shortcuts.fold.layout_cycle",
                "Switch to next / previous layout"
            )
        case .width:
            return L("shortcuts.fold.width", "Shrink / grow width")
        case .height:
            return L("shortcuts.fold.height", "Shrink / grow height")
        default:
            return ""
        }
    }
}
