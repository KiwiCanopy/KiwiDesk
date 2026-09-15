import KiwiDeskCore
import SwiftUI

/// The Space Bar card's row builders, split from
/// `SpaceBarCard.swift` for the file ceiling. One builder per
/// census row; the Auto/value pairs render at the Auto key as
/// one `AutoGatedGroup` (the value key is that group's slider,
/// so it builds nothing of its own).
extension SpaceBarCard {
    @ViewBuilder func spaceBarRow(_ key: SpaceBarKey) -> some View {
        switch key {
        case .spaceBarEnabled:
            showToggle
        case .spaceBarEdge:
            edgeRow
        case .spaceBarThickness:
            PtSlider(
                label: L("space_bar.thickness", "Thickness"),
                value: style.thickness,
                range: BarSliderBands.thickness
            )
        case .spaceBarShowFrontApp:
            ToggleRow(
                label: L(
                    "space_bar.show_front_app",
                    "Show front app"
                ),
                isOn: style.showFrontApp,
                help: L(
                    "space_bar.show_front_app.help",
                    "Adds a trailing segment with the focused "
                        + "window of the Space each display "
                        + "currently shows. Icon-only on vertical "
                        + "bars."
                )
            )
        case .spaceBarHideEmpty:
            ToggleRow(
                label: L(
                    "space_bar.hide_empty",
                    "Hide empty Spaces"
                ),
                isOn: style.hideEmpty,
                help: L(
                    "space_bar.hide_empty.help",
                    "Spaces with no windows are hidden from the "
                        + "bar, except the Space you're currently "
                        + "on. Use a shortcut to jump to a hidden "
                        + "Space."
                )
            )
        case .spaceBarBackground:
            SegmentedPicker(
                L(
                    "space_bar.background_style.label",
                    "Background style"
                ),
                selection: style.backgroundStyle,
                options: AppBarOptions.backgroundStyle
                    .map { ($0.1, $0.0) }
            )
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleBackground
            )
        case .spaceBarLiquidGlass:
            // Lua-only since #1307 (see `AppBarCard+Rows`).
            EmptyView()
        case .spaceBarBackgroundFit:
            backgroundFitRow
                .searchAnchored(
                    SettingsCatalog.bars.spaceBarStyle.children
                        .spaceBarStyleBackgroundFit
                )
        case .spaceBarAlignment:
            SegmentedPicker(
                L("space_bar.alignment.label", "Alignment"),
                selection: style.alignment,
                options: AppBarOptions.alignment
                    .map { ($0.1, $0.0) },
                // Option names interpolated from picker keys (#818).
                help: L(
                    "space_bar.alignment.label.help",
                    "Where the Space items — and the front-app "
                        + "segment, when shown — sit along the "
                        + "bar. \u{201C}%1$@\u{201D} and "
                        + "\u{201C}%2$@\u{201D} follow the edge, "
                        + "so on a left bar the start of the bar "
                        + "is its top.",
                    L("app_bar.alignment.start", "Start"),
                    L("app_bar.alignment.end", "End")
                )
            )
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleAlignment
            )
        case .spaceBarActiveIndicator:
            SegmentedPicker(
                L(
                    "space_bar.active_indicator.label",
                    "Active indicator"
                ),
                selection: style.activeIndicator,
                options: AppBarOptions.activeIndicator
                    .filter { $0.0 != .gap }
                    .map { ($0.1, $0.0) }
            )
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleActiveIndicator
            )
        case .spaceBarIconSource:
            iconSourceRow
                .searchAnchored(
                    SettingsCatalog.bars.spaceBarStyle.children
                        .spaceBarStyleIconSource
                )
        case .spaceBarCornerRoundness:
            PtSlider(
                label: L(
                    "space_bar.corner_roundness",
                    "Corner roundness"
                ),
                value: style.cornerRoundness,
                range: 0...100,
                unit: "%"
            )
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleCornerRoundness
            )
        case .spaceBarItemSizeAuto:
            AutoGatedGroup(
                title: L(
                    "space_bar.item_size.auto",
                    "Auto item size"
                ),
                isOn: AutoSentinel.binding(
                    style.itemSize,
                    restore: 120
                )
            ) {
                PtSlider(
                    label: L("space_bar.item_size", "Item size"),
                    value: style.itemSize,
                    range: 1...200,
                    autoAtZero: true
                )
                .searchAnchored(
                    SettingsCatalog.bars.spaceBarStyle.children
                        .spaceBarStyleItemSize
                )
            }
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleItemSizeAuto
            )
        case .spaceBarItemGap:
            PtSlider(
                label: L("space_bar.item_gap", "Item gap"),
                value: style.itemGap,
                range: 0...40
            )
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleItemGap
            )
        case .spaceBarFontSizeAuto:
            AutoGatedGroup(
                title: L(
                    "space_bar.font_size.auto",
                    "Auto font size"
                ),
                isOn: AutoSentinel.binding(
                    style.fontSize,
                    restore: 14
                )
            ) {
                PtSlider(
                    label: L("space_bar.font_size", "Font size"),
                    value: style.fontSize,
                    range: 1...32,
                    autoAtZero: true
                )
                .searchAnchored(
                    SettingsCatalog.bars.spaceBarStyle.children
                        .spaceBarStyleFontSize
                )
            }
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleFontSizeAuto
            )
        case .spaceBarGlyphCap:
            glyphCapRow
        case .spaceBarTitleCap:
            titleCapRow
                .searchAnchored(
                    SettingsCatalog.bars.spaceBarStyle.children
                        .spaceBarStyleTitleCap
                )
        case .spaceBarSpringDelay:
            SecondsRow(
                label: L("space_bar.spring_delay", "Spring delay"),
                ms: style.springDelay,
                range: BarSliderBands.springDelaySeconds,
                help: L(
                    "space_bar.spring_delay.help",
                    "Drag a window onto a Space and hold this "
                        + "long for the view to spring to that "
                        + "Space, so you can drop the window into "
                        + "its layout. A quicker drop moves the "
                        + "window there without switching."
                )
            )
            .searchAnchored(
                SettingsCatalog.bars.spaceBarStyle.children
                    .spaceBarStyleSpringDelay
            )
        case .spaceBarItemSize, .spaceBarFontSize:
            EmptyView()
        case .spaceBarDimFactor, .spaceBarActiveDimFactor,
            .spaceBarStickyBadge, .copyAppearance,
            .spaceBarItemColor, .spaceBarActiveItemColor,
            .spaceBarFocusedItemColor, .spaceBarFillColor,
            .spaceBarHighlightColor, .spaceBarHoverFillColor,
            .spaceBarHoverItemColor, .spaceBarGroupBadgeColor,
            .spaceBarGroupBadgeTextColor:
            let _ = assertionFailure(
                "unrendered Space Bar census key: \(key.rawValue)"
            )
            EmptyView()
        }
    }
}
