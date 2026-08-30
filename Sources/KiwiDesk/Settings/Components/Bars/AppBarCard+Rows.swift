import KiwiDeskCore
import SwiftUI

/// The App Bar card's row builders, split from
/// `AppBarCard.swift` for the file ceiling. One builder per
/// census row; the Auto/value pairs render at the Auto key as
/// one `AutoGatedGroup`.
extension AppBarCard {
    @ViewBuilder func appBarRow(_ key: AppBarKey) -> some View {
        switch key {
        case .appBarEdge:
            edgeRow
        case .appBarThickness:
            PtSlider(
                label: L("app_bar.thickness", "Thickness"),
                value: style.thickness,
                range: 30...80
            )
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
        case .appBarBackground:
            SegmentedPicker(
                L(
                    "app_bar.background_style.label",
                    "Background style"
                ),
                selection: style.backgroundStyle,
                options: AppBarOptions.backgroundStyle
                    .map { ($0.1, $0.0) }
            )
        case .appBarLiquidGlass:
            // Hidden below macOS 26 (#390).
            if AppBarStyle.glassAvailable {
                ToggleRow(
                    label: L(
                        "app_bar.liquid_glass",
                        "Liquid Glass"
                    ),
                    isOn: style.liquidGlass,
                    help: L(
                        "app_bar.liquid_glass.help",
                        "Lays a translucent glass material over "
                            + "the boxes or the plate. The Fill "
                            + "color tints it, though the tint "
                            + "reads subtle on current macOS."
                    )
                )
            }
        case .appBarBackgroundFit:
            backgroundFitRow
        case .appBarAlignment:
            SegmentedPicker(
                L("app_bar.alignment.label", "Alignment"),
                selection: style.alignment,
                options: AppBarOptions.alignment
                    .map { ($0.1, $0.0) },
                help: L(
                    "app_bar.alignment.label.help",
                    "Where the item group sits along the bar "
                        + "while it fits. \u{201C}%1$@\u{201D} and "
                        + "\u{201C}%2$@\u{201D} follow the edge, "
                        + "so on a left bar the start of the bar "
                        + "is its top; once items overflow and "
                        + "scroll, all three behave the same.",
                    L("app_bar.alignment.start", "Start"),
                    L("app_bar.alignment.end", "End")
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
        case .appBarContent:
            contentRow
        case .appBarTitleCap:
            titleCapRow
        case .appBarIconSource:
            iconSourceRow
        case .appBarCornerRoundness:
            PtSlider(
                label: L(
                    "app_bar.corner_roundness",
                    "Corner roundness"
                ),
                value: style.cornerRoundness,
                range: 0...100,
                unit: "%"
            )
        case .appBarItemSizeAuto:
            AutoGatedGroup(
                title: L("app_bar.item_size.auto", "Auto item size"),
                isOn: AutoSentinel.binding(
                    style.itemSize,
                    restore: 120
                )
            ) {
                PtSlider(
                    label: L("app_bar.item_size", "Item size"),
                    value: style.itemSize,
                    range: 1...200,
                    autoAtZero: true
                )
            }
        case .appBarItemGap:
            PtSlider(
                label: L("app_bar.item_gap", "Item gap"),
                value: style.itemGap,
                range: 0...40
            )
        case .appBarFontSizeAuto:
            AutoGatedGroup(
                title: L("app_bar.font_size.auto", "Auto font size"),
                isOn: AutoSentinel.binding(
                    style.fontSize,
                    restore: 14
                )
            ) {
                PtSlider(
                    label: L("app_bar.font_size", "Font size"),
                    value: style.fontSize,
                    range: 1...32,
                    autoAtZero: true
                )
            }
        case .appBarItemSize, .appBarFontSize:
            EmptyView()
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

    /// Position plus the shared-edge info row directly under it (#374).
    @ViewBuilder private var edgeRow: some View {
        SegmentedPicker(
            L("app_bar.edge.label", "Position"),
            selection: style.edge,
            options: AppBarOptions.edge.map { ($0.1, $0.0) },
            help: L(
                "app_bar.edge.label.help",
                "Which screen edge the bar occupies. The bar "
                    + "reserves this edge in every layout that "
                    + "shows it."
            )
        )
        if model.config.settings.spaceBarSharesEdgeWithAppBar {
            BarSameEdgeRow(
                edge: model.config.settings.spaceBarStyle.edge
            )
        }
    }

    private var backgroundFitRow: some View {
        SegmentedPicker(
            L(
                "app_bar.background_fit.label",
                "Background size"
            ),
            selection: style.backgroundFit,
            options: AppBarOptions.backgroundFit
                .map { ($0.1, $0.0) }
        )
        .modifier(
            GreyOut(
                // Inert when Boxed (#660, #818).
                active: gates.everyShownBarBoxed,
                help: L(
                    "app_bar.background_fit.boxed_only",
                    "\u{201C}%1$@\u{201D} draws a box per item, "
                        + "not a shared plate, so there is "
                        + "nothing to size.",
                    L("app_bar.background_style.boxed", "Boxed")
                )
            )
        )
    }
}
