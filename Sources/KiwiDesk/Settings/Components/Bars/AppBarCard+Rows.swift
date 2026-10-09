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
        case .appBarTitleCap:
            titleCapRow
        case .appBarReserve:
            // Lua/CLI only (#1524): no row draws it.
            let _ = assertionFailure(
                "unrendered App Bar census key: \(key.rawValue)"
            )
            EmptyView()
        }
    }

    /// Window title character length cap (#901, #937).
    var titleCapRow: some View {
        StepperRow(
            label: L("app_bar.title_cap", "Title length"),
            value: style.titleCap,
            in: AppBarStyle.titleCapRange,
            help: L(
                "app_bar.title_cap.help",
                "How many characters of a window's title an "
                    + "item shows before it is shortened. "
                    + "Grouped windows show their app's name "
                    + "instead, which is never shortened."
            )
        )
    }
}
