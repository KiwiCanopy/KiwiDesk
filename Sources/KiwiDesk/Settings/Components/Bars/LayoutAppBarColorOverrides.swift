import KiwiDeskCore
import SwiftUI

// Split from `AppBarLayoutGroup.swift` for the file
// ceiling (#527 review) - the `AppBarGroups+Colors.swift`
// sibling split, same reason.
/// The color override rows, in `AppBarColorGrid` so they read
/// as the same 2-column grid as Global's colors (#2). Field
/// order mirrors the global editor — the inline pair (Fill,
/// Highlight) first, then the rest of the palette — so a field
/// keeps the same reading order in both editors. (Column
/// positions match only for the inline pair: Global splits its
/// colors into an inline grid plus an advanced disclosure, while
/// these eight flow as one continuous grid.)
struct LayoutAppBarColorOverrides: View {
    @Binding var bar: LayoutAppBar
    let global: AppBarStyle

    var body: some View {
        AppBarColorGrid {
            OverrideColorRow(
                label: L("app_bar.color.fill", "Fill"),
                value: $bar.fillColor,
                global: global.fillColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.highlight",
                    "Highlight"
                ),
                value: $bar.highlightColor,
                global: global.highlightColor
            )
            OverrideColorRow(
                label: L("app_bar.color.item", "Item"),
                value: $bar.itemColor,
                global: global.itemColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.active_item",
                    "Active item"
                ),
                value: $bar.activeItemColor,
                global: global.activeItemColor
            )
            OverrideColorRow(
                label: L("app_bar.color.hover_fill", "Hover fill"),
                value: $bar.hoverFillColor,
                global: global.hoverFillColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.hover_item",
                    "Hover item"
                ),
                value: $bar.hoverItemColor,
                global: global.hoverItemColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.group_badge",
                    "Group badge"
                ),
                value: $bar.groupBadgeColor,
                global: global.groupBadgeColor
            )
            OverrideColorRow(
                label: L(
                    "app_bar.color.badge_text",
                    "Badge text"
                ),
                value: $bar.groupBadgeTextColor,
                global: global.groupBadgeTextColor
            )
        }
    }
}
