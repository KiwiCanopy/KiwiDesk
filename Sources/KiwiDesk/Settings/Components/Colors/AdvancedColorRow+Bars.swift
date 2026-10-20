import KiwiDeskCore
import SwiftUI

/// Advanced color swatch rows for the shelf and the Space Bar.
extension AdvancedColorRow {
    @ViewBuilder func kiwishelfRow(_ key: KiwiShelfKey) -> some View {
        let shelf = settings.kiwishelf
        switch key {
        case .fillColor:
            HexColorField(
                label: L("kiwishelf.color.fill", "Fill"),
                hex: shelf.fillColor
            )
        case .itemColor:
            HexColorField(
                label: L("kiwishelf.color.item", "Item"),
                hex: shelf.itemColor
            )
            .help(
                L(
                    "kiwishelf.color.item.help",
                    "Text and glyphs on both bars. A Space you are "
                        + "not on draws it dimmed."
                )
            )
        case .activeItemColor:
            HexColorField(
                label: L("kiwishelf.color.active_item", "Active item"),
                hex: shelf.activeItemColor
            )
        case .highlightColor:
            HexColorField(
                label: L("kiwishelf.color.highlight", "Highlight"),
                hex: shelf.highlightColor
            )
        case .hoverFillColor:
            HexColorField(
                label: L("kiwishelf.color.hover_fill", "Hover fill"),
                hex: shelf.hoverFillColor
            )
        case .hoverItemColor:
            HexColorField(
                label: L("kiwishelf.color.hover_item", "Hover item"),
                hex: shelf.hoverItemColor
            )
        case .groupBadgeColor:
            HexColorField(
                label: L("kiwishelf.color.group_badge", "Group badge"),
                hex: shelf.groupBadgeColor
            )
        case .groupBadgeTextColor:
            HexColorField(
                label: L("kiwishelf.color.badge_text", "Badge text"),
                hex: shelf.groupBadgeTextColor
            )
        case .borderColor:
            HexColorField(
                label: L("kiwishelf.color.border", "Border"),
                a11yLabel: L(
                    "kiwishelf.color.border.a11y",
                    "KiwiShelf border color"
                ),
                hex: shelf.borderColor
            )
        default:
            let _ = assertionFailure(
                "non-colour KiwiShelf key in Colors & glass: "
                    + key.rawValue
            )
            EmptyView()
        }
    }

    @ViewBuilder func spaceBarRow(_ key: SpaceBarKey) -> some View {
        let style = settings.spaceBarStyle
        switch key {
        case .spaceBarFocusedItemColor:
            HexColorField(
                label: L(
                    "space_bar.color.focused_item",
                    "Focused window"
                ),
                hex: style.focusedItemColor
            )
        case .spaceBarFocusedHighlightColor:
            HexColorField(
                label: L(
                    "space_bar.color.focused_highlight",
                    "Front app indicator"
                ),
                automatic: true,
                follows: ColorFollow(
                    hex: style.wrappedValue.focusedItemColor,
                    label: L(
                        "space_bar.color.focused_item",
                        "Focused window"
                    )
                ),
                hex: style.focusedHighlightColor
            )
            .help(focusedHighlightHelp)
        default:
            let _ = assertionFailure(
                "non-colour Space Bar key in Colors & glass: "
                    + key.rawValue
            )
            EmptyView()
        }
    }

    /// Automatic is the front app's own focused-window colour, by
    /// that row's own key (#818, #1856).
    private var focusedHighlightHelp: String {
        L(
            "space_bar.color.focused_highlight.help",
            "The outline or edge mark around the front-app segment. "
                + "Automatic uses \u{201C}%1$@\u{201D}.",
            L("space_bar.color.focused_item", "Focused window")
        )
    }
}
