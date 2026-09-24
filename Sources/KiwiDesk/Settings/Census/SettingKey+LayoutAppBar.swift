/// Per-layout App Bar census slice (`LayoutAppBar`, Monocle and
/// Scrolling): whether each layout shows one — drawn in the
/// KiwiShelf card — and its Lua-only overrides of the bar's OWN
/// fields; the shelf's fields have none (#1517).

enum LayoutAppBarKey: String, CaseIterable, Hashable {
    case monocleAppBarEnabled = "settings.monocle.appBar.enabled"
    case monocleAppBarActiveIndicator =
        "settings.monocle.appBar.activeIndicator"
    case monocleAppBarContent = "settings.monocle.appBar.content"
    case monocleAppBarTitleCap = "settings.monocle.appBar.titleCap"
    case monocleAppBarGroupAdjacentWindows =
        "settings.monocle.appBar.groupAdjacentWindows"
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
    case monocleAppBarIconSource = "settings.monocle.appBar.iconSource"
    case monocleAppBarDimFactor = "settings.monocle.appBar.dimFactor"
    case scrollingAppBarEnabled = "settings.scrolling.appBar.enabled"
    case scrollingAppBarActiveIndicator =
        "settings.scrolling.appBar.activeIndicator"
    case scrollingAppBarContent = "settings.scrolling.appBar.content"
    case scrollingAppBarTitleCap = "settings.scrolling.appBar.titleCap"
    case scrollingAppBarGroupAdjacentWindows =
        "settings.scrolling.appBar.groupAdjacentWindows"
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
    case scrollingAppBarIconSource = "settings.scrolling.appBar.iconSource"
    case scrollingAppBarDimFactor = "settings.scrolling.appBar.dimFactor"
}

extension LayoutAppBarKey {
    var placement: SettingPlacement {
        switch self {
        case .monocleAppBarEnabled, .scrollingAppBarEnabled:
            // Drawn in the KiwiShelf card's Show group, which has
            // no container gate.
            return .row(.bars, .kiwishelf, .atRest)
        case .monocleAppBarActiveIndicator, .monocleAppBarContent,
            .monocleAppBarTitleCap, .monocleAppBarGroupAdjacentWindows,
            .monocleAppBarFillColor, .monocleAppBarHighlightColor,
            .monocleAppBarItemColor, .monocleAppBarActiveItemColor,
            .monocleAppBarHoverFillColor, .monocleAppBarHoverItemColor,
            .monocleAppBarGroupBadgeColor, .monocleAppBarGroupBadgeTextColor,
            .monocleAppBarIconSource, .monocleAppBarDimFactor,
            .scrollingAppBarActiveIndicator, .scrollingAppBarContent,
            .scrollingAppBarTitleCap, .scrollingAppBarGroupAdjacentWindows,
            .scrollingAppBarFillColor, .scrollingAppBarHighlightColor,
            .scrollingAppBarItemColor, .scrollingAppBarActiveItemColor,
            .scrollingAppBarHoverFillColor, .scrollingAppBarHoverItemColor,
            .scrollingAppBarGroupBadgeColor,
            .scrollingAppBarGroupBadgeTextColor, .scrollingAppBarIconSource,
            .scrollingAppBarDimFactor:
            return .luaOnly
        }
    }
}

extension LayoutAppBarKey {
    var text: SettingRowText {
        switch self {
        case .monocleAppBarEnabled:
            return .text("kiwishelf.show.monocle")
        case .scrollingAppBarEnabled:
            return .text("kiwishelf.show.scrolling")
        case .monocleAppBarActiveIndicator, .monocleAppBarContent,
            .monocleAppBarTitleCap, .monocleAppBarGroupAdjacentWindows,
            .monocleAppBarFillColor, .monocleAppBarHighlightColor,
            .monocleAppBarItemColor, .monocleAppBarActiveItemColor,
            .monocleAppBarHoverFillColor, .monocleAppBarHoverItemColor,
            .monocleAppBarGroupBadgeColor, .monocleAppBarGroupBadgeTextColor,
            .monocleAppBarIconSource, .monocleAppBarDimFactor,
            .scrollingAppBarActiveIndicator, .scrollingAppBarContent,
            .scrollingAppBarTitleCap, .scrollingAppBarGroupAdjacentWindows,
            .scrollingAppBarFillColor, .scrollingAppBarHighlightColor,
            .scrollingAppBarItemColor, .scrollingAppBarActiveItemColor,
            .scrollingAppBarHoverFillColor, .scrollingAppBarHoverItemColor,
            .scrollingAppBarGroupBadgeColor,
            .scrollingAppBarGroupBadgeTextColor, .scrollingAppBarIconSource,
            .scrollingAppBarDimFactor:
            return .none
        }
    }
}
