import KiwiDeskCore
import SwiftUI

/// The App Bar card's row builders, split from
/// `AppBarCard.swift` for the file ceiling. One builder per
/// census row; the Auto/value pairs render at the Auto key as
/// one `AutoGatedGroup`.
extension AppBarCard {
    @ViewBuilder func appBarRow(_ key: AppBarKey) -> some View {
        switch key {
        case .appBarGroupAdjacentWindows:
            ToggleRow(
                label: L(
                    "app_bar.group_adjacent",
                    "Group adjacent same-app windows"
                ),
                isOn: style.groupAdjacentWindows,
                help: L(
                    "app_bar.group_adjacent.help",
                    "Merges neighbouring windows of the same app "
                        + "into a single item, marked with a "
                        + "count badge, instead of showing one "
                        + "item each."
                )
            )
        case .appBarActiveIndicator:
            SegmentedPicker(
                L(
                    "app_bar.active_indicator.label",
                    "Active indicator"
                ),
                selection: style.activeIndicator,
                options: AppBarOptions.activeIndicator
                    .map { ($0.1, $0.0) }
            )
            .searchAnchored(
                SettingsCatalog.bars.appBarStyle.children
                    .appBarStyleActiveIndicator
            )
        case .appBarContent:
            contentRow
                .searchAnchored(
                    SettingsCatalog.bars.appBarStyle.children
                        .appBarStyleContent
                )
        case .appBarTitleCap:
            titleCapRow
                .searchAnchored(
                    SettingsCatalog.bars.appBarStyle.children
                        .appBarStyleTitleCap
                )
        case .appBarIconSource:
            iconSourceRow
                .searchAnchored(
                    SettingsCatalog.bars.appBarStyle.children
                        .appBarStyleIconSource
                )
        case .appBarDimFactor, .appBarFillColor,
            .appBarHighlightColor, .appBarItemColor,
            .appBarActiveItemColor, .appBarHoverFillColor,
            .appBarHoverItemColor, .appBarGroupBadgeColor,
            .appBarGroupBadgeTextColor:
            let _ = assertionFailure(
                "unrendered App Bar census key: \(key.rawValue)"
            )
            EmptyView()
        }
    }
}
