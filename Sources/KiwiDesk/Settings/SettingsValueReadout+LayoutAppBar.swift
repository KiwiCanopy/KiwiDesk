import KiwiDeskCore

/// Per-layout App Bar override rows (`LayoutAppBar`, Monocle
/// and Scrolling). Every look field is a nullable override —
/// nil inherits the global style — so each row narrates three
/// states: a set value takes the same formatter as its global
/// twin, an inherited side shows the core's `unset` "—", and a
/// gained override reads "— → 44 pt". The value formatters and
/// the row shape live in
/// `SettingsValueReadout+LayoutAppBarValues.swift`.
extension SettingsValueReadout {
    static func layoutAppBarRows(
        _ key: LayoutAppBarKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.layoutAppBar(key)
        let mode = layoutBarMode(key)
        let o = layoutBar(old, mode)
        let n = layoutBar(new, mode)
        switch key {
        case .monocleAppBarEnabled, .scrollingAppBarEnabled:
            // The one always-present field; the census label is
            // already the layout's own name.
            return [
                .change(
                    census,
                    label: label(for: census),
                    old: onOff(o.enabled),
                    new: onOff(n.enabled)
                )
            ]
        case .monocleAppBarEdge, .scrollingAppBarEdge:
            return layoutBarRow(
                census,
                mode,
                .appBarEdge,
                layoutBarChoice(o.edge, AppBarOptions.edge),
                layoutBarChoice(n.edge, AppBarOptions.edge)
            )
        case .monocleAppBarAlignment, .scrollingAppBarAlignment:
            return layoutBarRow(
                census,
                mode,
                .appBarAlignment,
                layoutBarChoice(o.alignment, AppBarOptions.alignment),
                layoutBarChoice(n.alignment, AppBarOptions.alignment)
            )
        case .monocleAppBarBackgroundStyle,
            .scrollingAppBarBackgroundStyle:
            return layoutBarRow(
                census,
                mode,
                .appBarBackground,
                layoutBarChoice(
                    o.backgroundStyle,
                    AppBarOptions.backgroundStyle
                ),
                layoutBarChoice(
                    n.backgroundStyle,
                    AppBarOptions.backgroundStyle
                )
            )
        case .monocleAppBarBackgroundFit,
            .scrollingAppBarBackgroundFit:
            return layoutBarRow(
                census,
                mode,
                .appBarBackgroundFit,
                layoutBarChoice(
                    o.backgroundFit,
                    AppBarOptions.backgroundFit
                ),
                layoutBarChoice(
                    n.backgroundFit,
                    AppBarOptions.backgroundFit
                )
            )
        case .monocleAppBarActiveIndicator,
            .scrollingAppBarActiveIndicator:
            return layoutBarRow(
                census,
                mode,
                .appBarActiveIndicator,
                layoutBarChoice(
                    o.activeIndicator,
                    AppBarOptions.activeIndicator
                ),
                layoutBarChoice(
                    n.activeIndicator,
                    AppBarOptions.activeIndicator
                )
            )
        case .monocleAppBarContent, .scrollingAppBarContent:
            return layoutBarRow(
                census,
                mode,
                .appBarContent,
                layoutBarChoice(o.content, AppBarOptions.content),
                layoutBarChoice(n.content, AppBarOptions.content)
            )
        case .monocleAppBarIconSource, .scrollingAppBarIconSource:
            return layoutBarRow(
                census,
                mode,
                .appBarIconSource,
                layoutBarChoice(
                    o.iconSource,
                    AppBarOptions.iconSource
                ),
                layoutBarChoice(
                    n.iconSource,
                    AppBarOptions.iconSource
                )
            )
        case .monocleAppBarGroupAdjacentWindows,
            .scrollingAppBarGroupAdjacentWindows:
            return layoutBarRow(
                census,
                mode,
                .appBarGroupAdjacentWindows,
                layoutBarOnOff(o.groupAdjacentWindows),
                layoutBarOnOff(n.groupAdjacentWindows)
            )
        case .monocleAppBarLiquidGlass,
            .scrollingAppBarLiquidGlass:
            return layoutBarRow(
                census,
                mode,
                .appBarLiquidGlass,
                layoutBarOnOff(o.liquidGlass),
                layoutBarOnOff(n.liquidGlass)
            )
        case .monocleAppBarThickness, .scrollingAppBarThickness:
            return layoutBarRow(
                census,
                mode,
                .appBarThickness,
                layoutBarPoints(o.thickness),
                layoutBarPoints(n.thickness)
            )
        case .monocleAppBarItemSize, .scrollingAppBarItemSize:
            return layoutBarRow(
                census,
                mode,
                .appBarItemSize,
                layoutBarAutoPoints(o.itemSize),
                layoutBarAutoPoints(n.itemSize)
            )
        case .monocleAppBarItemGap, .scrollingAppBarItemGap:
            return layoutBarRow(
                census,
                mode,
                .appBarItemGap,
                layoutBarPoints(o.itemGap),
                layoutBarPoints(n.itemGap)
            )
        case .monocleAppBarFontSize, .scrollingAppBarFontSize:
            return layoutBarRow(
                census,
                mode,
                .appBarFontSize,
                layoutBarAutoPoints(o.fontSize),
                layoutBarAutoPoints(n.fontSize)
            )
        case .monocleAppBarCornerRoundness,
            .scrollingAppBarCornerRoundness:
            return layoutBarRow(
                census,
                mode,
                .appBarCornerRoundness,
                layoutBarRoundness(o.cornerRoundness),
                layoutBarRoundness(n.cornerRoundness)
            )
        case .monocleAppBarDimFactor, .scrollingAppBarDimFactor:
            return layoutBarRow(
                census,
                mode,
                .appBarDimFactor,
                layoutBarNumber(o.dimFactor),
                layoutBarNumber(n.dimFactor)
            )
        case .monocleAppBarFillColor, .scrollingAppBarFillColor:
            return layoutBarRow(
                census,
                mode,
                .appBarFillColor,
                layoutBarHex(o.fillColor),
                layoutBarHex(n.fillColor)
            )
        case .monocleAppBarHighlightColor,
            .scrollingAppBarHighlightColor:
            return layoutBarRow(
                census,
                mode,
                .appBarHighlightColor,
                layoutBarHex(o.highlightColor),
                layoutBarHex(n.highlightColor)
            )
        case .monocleAppBarItemColor, .scrollingAppBarItemColor:
            return layoutBarRow(
                census,
                mode,
                .appBarItemColor,
                layoutBarHex(o.itemColor),
                layoutBarHex(n.itemColor)
            )
        case .monocleAppBarActiveItemColor,
            .scrollingAppBarActiveItemColor:
            return layoutBarRow(
                census,
                mode,
                .appBarActiveItemColor,
                layoutBarHex(o.activeItemColor),
                layoutBarHex(n.activeItemColor)
            )
        case .monocleAppBarHoverFillColor,
            .scrollingAppBarHoverFillColor:
            return layoutBarRow(
                census,
                mode,
                .appBarHoverFillColor,
                layoutBarHex(o.hoverFillColor),
                layoutBarHex(n.hoverFillColor)
            )
        case .monocleAppBarHoverItemColor,
            .scrollingAppBarHoverItemColor:
            return layoutBarRow(
                census,
                mode,
                .appBarHoverItemColor,
                layoutBarHex(o.hoverItemColor),
                layoutBarHex(n.hoverItemColor)
            )
        case .monocleAppBarGroupBadgeColor,
            .scrollingAppBarGroupBadgeColor:
            return layoutBarRow(
                census,
                mode,
                .appBarGroupBadgeColor,
                layoutBarHex(o.groupBadgeColor),
                layoutBarHex(n.groupBadgeColor)
            )
        case .monocleAppBarGroupBadgeTextColor,
            .scrollingAppBarGroupBadgeTextColor:
            return layoutBarRow(
                census,
                mode,
                .appBarGroupBadgeTextColor,
                layoutBarHex(o.groupBadgeTextColor),
                layoutBarHex(n.groupBadgeTextColor)
            )
        }
    }

    /// The stored override struct the key narrates.
    private static func layoutBar(
        _ config: GuiConfig,
        _ mode: LayoutMode
    ) -> LayoutAppBar {
        mode == .monocle
            ? config.settings.monocle.appBar
            : config.settings.scrolling.appBar
    }

    /// Which layout a key narrates — explicit, so a third layout
    /// growing a bar cannot silently misroute to Scrolling.
    private static func layoutBarMode(
        _ key: LayoutAppBarKey
    ) -> LayoutMode {
        switch key {
        case .monocleAppBarEnabled, .monocleAppBarEdge,
            .monocleAppBarAlignment, .monocleAppBarBackgroundStyle,
            .monocleAppBarBackgroundFit,
            .monocleAppBarActiveIndicator, .monocleAppBarContent,
            .monocleAppBarGroupAdjacentWindows,
            .monocleAppBarThickness, .monocleAppBarItemSize,
            .monocleAppBarItemGap, .monocleAppBarFontSize,
            .monocleAppBarCornerRoundness, .monocleAppBarFillColor,
            .monocleAppBarHighlightColor, .monocleAppBarItemColor,
            .monocleAppBarActiveItemColor,
            .monocleAppBarHoverFillColor,
            .monocleAppBarHoverItemColor,
            .monocleAppBarGroupBadgeColor,
            .monocleAppBarGroupBadgeTextColor,
            .monocleAppBarLiquidGlass, .monocleAppBarIconSource,
            .monocleAppBarDimFactor:
            return .monocle
        case .scrollingAppBarEnabled, .scrollingAppBarEdge,
            .scrollingAppBarAlignment,
            .scrollingAppBarBackgroundStyle,
            .scrollingAppBarBackgroundFit,
            .scrollingAppBarActiveIndicator,
            .scrollingAppBarContent,
            .scrollingAppBarGroupAdjacentWindows,
            .scrollingAppBarThickness, .scrollingAppBarItemSize,
            .scrollingAppBarItemGap, .scrollingAppBarFontSize,
            .scrollingAppBarCornerRoundness,
            .scrollingAppBarFillColor,
            .scrollingAppBarHighlightColor,
            .scrollingAppBarItemColor,
            .scrollingAppBarActiveItemColor,
            .scrollingAppBarHoverFillColor,
            .scrollingAppBarHoverItemColor,
            .scrollingAppBarGroupBadgeColor,
            .scrollingAppBarGroupBadgeTextColor,
            .scrollingAppBarLiquidGlass,
            .scrollingAppBarIconSource, .scrollingAppBarDimFactor:
            return .scrolling
        }
    }
}
