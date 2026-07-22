import KiwiDeskCore
import SwiftUI

/// The App Bar color rows (#374), split from
/// `AppBarSections.swift` for the file ceiling — the
/// `SpaceBarColorsGroup` sibling. The disclosure's `@State`
/// stays in `GlobalAppBarGroup` (extensions can't hold
/// state); only the row builders live here.
extension GlobalAppBarGroup {
    // The two the preview reflects most, kept inline: the fill
    // under the tabs and the active-tab indicator accent.
    @ViewBuilder var inlineColors: some View {
        HexColorField(
            label: L("app_bar.color.fill", "Fill"),
            hex: $style.fillColor
        )
        HexColorField(
            label: L("app_bar.color.highlight", "Highlight"),
            hex: $style.highlightColor
        )
    }

    // The remaining palette, behind the disclosure.
    @ViewBuilder var advancedColors: some View {
        Group {
            HexColorField(
                label: L("app_bar.color.item", "Item"),
                hex: $style.itemColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.active_item",
                    "Active item"
                ),
                hex: $style.activeItemColor
            )
            HexColorField(
                label: L("app_bar.color.hover_fill", "Hover fill"),
                hex: $style.hoverFillColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.hover_item",
                    "Hover item"
                ),
                hex: $style.hoverItemColor
            )
        }
        Group {
            HexColorField(
                label: L(
                    "app_bar.color.group_badge",
                    "Group badge"
                ),
                hex: $style.groupBadgeColor
            )
            HexColorField(
                label: L(
                    "app_bar.color.badge_text",
                    "Badge text"
                ),
                hex: $style.groupBadgeTextColor
            )
        }
    }
}
