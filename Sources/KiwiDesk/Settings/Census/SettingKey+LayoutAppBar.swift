/// Per-layout App Bar overrides census slice (`LayoutAppBar`, Monocle and
/// Scrolling).

enum LayoutAppBarKey: String, CaseIterable, Hashable {
    case monocleAppBarEnabled = "settings.monocle.appBar.enabled"
    case monocleAppBarEdge = "settings.monocle.appBar.edge"
    case monocleAppBarAlignment = "settings.monocle.appBar.alignment"
    case monocleAppBarBackgroundStyle =
        "settings.monocle.appBar.backgroundStyle"
    case monocleAppBarBackgroundFit = "settings.monocle.appBar.backgroundFit"
    case monocleAppBarActiveIndicator =
        "settings.monocle.appBar.activeIndicator"
    case monocleAppBarContent = "settings.monocle.appBar.content"
    case monocleAppBarTitleCap = "settings.monocle.appBar.titleCap"
    case monocleAppBarGroupAdjacentWindows =
        "settings.monocle.appBar.groupAdjacentWindows"
    case monocleAppBarThickness = "settings.monocle.appBar.thickness"
    case monocleAppBarItemSize = "settings.monocle.appBar.itemSize"
    case monocleAppBarItemGap = "settings.monocle.appBar.itemGap"
    case monocleAppBarFontSize = "settings.monocle.appBar.fontSize"
    case monocleAppBarCornerRoundness =
        "settings.monocle.appBar.cornerRoundness"
    case monocleAppBarFillColor = "settings.monocle.appBar.fillColor"
    case monocleAppBarHighlightColor = "settings.monocle.appBar.highlightColor"
    case monocleAppBarItemColor = "settings.monocle.appBar.itemColor"
    case monocleAppBarActiveItemColor =
        "settings.monocle.appBar.activeItemColor"
    case monocleAppBarHoverFillColor = "settings.monocle.appBar.hoverFillColor"
    case monocleAppBarHoverItemColor = "settings.monocle.appBar.hoverItemColor"
    case monocleAppBarGroupBadgeColor =
        "settings.monocle.appBar.groupBadgeColor"
    case monocleAppBarGroupBadgeTextColor =
        "settings.monocle.appBar.groupBadgeTextColor"
    case monocleAppBarLiquidGlass = "settings.monocle.appBar.liquidGlass"
    case monocleAppBarIconSource = "settings.monocle.appBar.iconSource"
    case monocleAppBarDimFactor = "settings.monocle.appBar.dimFactor"
    case scrollingAppBarEnabled = "settings.scrolling.appBar.enabled"
    case scrollingAppBarEdge = "settings.scrolling.appBar.edge"
    case scrollingAppBarAlignment = "settings.scrolling.appBar.alignment"
    case scrollingAppBarBackgroundStyle =
        "settings.scrolling.appBar.backgroundStyle"
    case scrollingAppBarBackgroundFit =
        "settings.scrolling.appBar.backgroundFit"
    case scrollingAppBarActiveIndicator =
        "settings.scrolling.appBar.activeIndicator"
    case scrollingAppBarContent = "settings.scrolling.appBar.content"
    case scrollingAppBarTitleCap = "settings.scrolling.appBar.titleCap"
    case scrollingAppBarGroupAdjacentWindows =
        "settings.scrolling.appBar.groupAdjacentWindows"
    case scrollingAppBarThickness = "settings.scrolling.appBar.thickness"
    case scrollingAppBarItemSize = "settings.scrolling.appBar.itemSize"
    case scrollingAppBarItemGap = "settings.scrolling.appBar.itemGap"
    case scrollingAppBarFontSize = "settings.scrolling.appBar.fontSize"
    case scrollingAppBarCornerRoundness =
        "settings.scrolling.appBar.cornerRoundness"
    case scrollingAppBarFillColor = "settings.scrolling.appBar.fillColor"
    case scrollingAppBarHighlightColor =
        "settings.scrolling.appBar.highlightColor"
    case scrollingAppBarItemColor = "settings.scrolling.appBar.itemColor"
    case scrollingAppBarActiveItemColor =
        "settings.scrolling.appBar.activeItemColor"
    case scrollingAppBarHoverFillColor =
        "settings.scrolling.appBar.hoverFillColor"
    case scrollingAppBarHoverItemColor =
        "settings.scrolling.appBar.hoverItemColor"
    case scrollingAppBarGroupBadgeColor =
        "settings.scrolling.appBar.groupBadgeColor"
    case scrollingAppBarGroupBadgeTextColor =
        "settings.scrolling.appBar.groupBadgeTextColor"
    case scrollingAppBarLiquidGlass = "settings.scrolling.appBar.liquidGlass"
    case scrollingAppBarIconSource = "settings.scrolling.appBar.iconSource"
    case scrollingAppBarDimFactor = "settings.scrolling.appBar.dimFactor"
}

extension LayoutAppBarKey {
    var placement: SettingPlacement {
        switch self {
        case .monocleAppBarEnabled, .scrollingAppBarEnabled:
            return .row(
                .bars,
                .appBar,
                .atRest,
                exemptFromContainerGate: true
            )
        case .monocleAppBarEdge, .monocleAppBarAlignment,
            .monocleAppBarBackgroundStyle, .monocleAppBarActiveIndicator,
            .monocleAppBarGroupAdjacentWindows, .monocleAppBarThickness,
            .monocleAppBarItemSize, .monocleAppBarItemGap,
            .monocleAppBarFontSize, .monocleAppBarCornerRoundness,
            .monocleAppBarFillColor, .monocleAppBarHighlightColor,
            .monocleAppBarItemColor, .monocleAppBarActiveItemColor,
            .monocleAppBarHoverFillColor, .monocleAppBarHoverItemColor,
            .monocleAppBarGroupBadgeColor, .monocleAppBarGroupBadgeTextColor,
            .scrollingAppBarEdge, .scrollingAppBarAlignment,
            .scrollingAppBarBackgroundStyle, .scrollingAppBarActiveIndicator,
            .scrollingAppBarGroupAdjacentWindows, .scrollingAppBarThickness,
            .scrollingAppBarItemSize, .scrollingAppBarItemGap,
            .scrollingAppBarFontSize, .scrollingAppBarCornerRoundness,
            .scrollingAppBarFillColor, .scrollingAppBarHighlightColor,
            .scrollingAppBarItemColor, .scrollingAppBarActiveItemColor,
            .scrollingAppBarHoverFillColor, .scrollingAppBarHoverItemColor,
            .scrollingAppBarGroupBadgeColor,
            .scrollingAppBarGroupBadgeTextColor,
            .monocleAppBarBackgroundFit, .monocleAppBarContent,
            .monocleAppBarTitleCap,
            .scrollingAppBarBackgroundFit, .scrollingAppBarContent,
            .scrollingAppBarTitleCap,
            .monocleAppBarLiquidGlass, .monocleAppBarIconSource,
            .monocleAppBarDimFactor, .scrollingAppBarLiquidGlass,
            .scrollingAppBarIconSource, .scrollingAppBarDimFactor:
            return .luaOnly
        }
    }
}

extension LayoutAppBarKey {
    var text: SettingRowText {
        switch self {
        case .monocleAppBarEnabled:
            return .text("layout.monocle.name")
        case .scrollingAppBarEnabled:
            return .text("layout.scrolling.name")
        case .monocleAppBarEdge, .monocleAppBarAlignment,
            .monocleAppBarBackgroundStyle, .monocleAppBarBackgroundFit,
            .monocleAppBarActiveIndicator, .monocleAppBarContent,
            .monocleAppBarTitleCap,
            .monocleAppBarGroupAdjacentWindows, .monocleAppBarThickness,
            .monocleAppBarItemSize, .monocleAppBarItemGap,
            .monocleAppBarFontSize, .monocleAppBarCornerRoundness,
            .monocleAppBarFillColor, .monocleAppBarHighlightColor,
            .monocleAppBarItemColor, .monocleAppBarActiveItemColor,
            .monocleAppBarHoverFillColor, .monocleAppBarHoverItemColor,
            .monocleAppBarGroupBadgeColor, .monocleAppBarGroupBadgeTextColor,
            .monocleAppBarLiquidGlass, .monocleAppBarIconSource,
            .monocleAppBarDimFactor, .scrollingAppBarEdge,
            .scrollingAppBarAlignment, .scrollingAppBarBackgroundStyle,
            .scrollingAppBarBackgroundFit, .scrollingAppBarActiveIndicator,
            .scrollingAppBarContent, .scrollingAppBarTitleCap,
            .scrollingAppBarGroupAdjacentWindows,
            .scrollingAppBarThickness, .scrollingAppBarItemSize,
            .scrollingAppBarItemGap, .scrollingAppBarFontSize,
            .scrollingAppBarCornerRoundness, .scrollingAppBarFillColor,
            .scrollingAppBarHighlightColor, .scrollingAppBarItemColor,
            .scrollingAppBarActiveItemColor, .scrollingAppBarHoverFillColor,
            .scrollingAppBarHoverItemColor, .scrollingAppBarGroupBadgeColor,
            .scrollingAppBarGroupBadgeTextColor, .scrollingAppBarLiquidGlass,
            .scrollingAppBarIconSource, .scrollingAppBarDimFactor:
            return .none
        }
    }
}
