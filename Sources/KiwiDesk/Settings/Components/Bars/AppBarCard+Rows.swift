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
                range: BarSliderBands.thickness
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
            .searchAnchored(
                SettingsCatalog.bars.appBarStyle.children.appBarStyleBackground
            )
        case .appBarLiquidGlass:
            // Lua-only since #1307: the one Liquid Glass switch
            // lives on Colours & Animations and writes this leaf
            // with the other two.
            EmptyView()
        case .appBarBackgroundFit:
            backgroundFitRow
                .searchAnchored(
                    SettingsCatalog.bars.appBarStyle.children
                        .appBarStyleBackgroundFit
                )
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
            .searchAnchored(
                SettingsCatalog.bars.appBarStyle.children.appBarStyleAlignment
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
            .searchAnchored(
                SettingsCatalog.bars.appBarStyle.children
                    .appBarStyleCornerRoundness
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
                .searchAnchored(
                    SettingsCatalog.bars.appBarStyle.children
                        .appBarStyleItemSize
                )
            }
            .searchAnchored(
                SettingsCatalog.bars.appBarStyle.children
                    .appBarStyleItemSizeAuto
            )
        case .appBarItemGap:
            PtSlider(
                label: L("app_bar.item_gap", "Item gap"),
                value: style.itemGap,
                range: 0...40
            )
            .searchAnchored(
                SettingsCatalog.bars.appBarStyle.children.appBarStyleItemGap
            )
        case .appBarOuterMargin:
            PtSlider(
                label: L("app_bar.outer_margin", "Outer margin"),
                value: style.outerMargin,
                range: BarSliderBands.margin,
                help: L(
                    "app_bar.outer_margin.help",
                    "Distance from the screen edge; 0 is flush."
                )
            )
            .searchAnchored(
                SettingsCatalog.bars.appBarStyle.children
                    .appBarStyleOuterMargin
            )
        case .appBarInnerMargin:
            PtSlider(
                label: L("app_bar.inner_margin", "Inner margin"),
                value: style.innerMargin,
                range: BarSliderBands.margin,
                help: L(
                    "app_bar.inner_margin.help",
                    "Extra room on the side facing the windows, on "
                        + "top of whatever gap already sits there; "
                        + "0 lets that gap govern."
                )
            )
            .searchAnchored(
                SettingsCatalog.bars.appBarStyle.children
                    .appBarStyleInnerMargin
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
                .searchAnchored(
                    SettingsCatalog.bars.appBarStyle.children
                        .appBarStyleFontSize
                )
            }
            .searchAnchored(
                SettingsCatalog.bars.appBarStyle.children
                    .appBarStyleFontSizeAuto
            )
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
