/// The global App Bar (`AppBarStyle`) slice of the census.

enum AppBarKey: String, CaseIterable, Hashable {
    case appBarEdge = "settings.appBarStyle.edge"
    case appBarAlignment = "settings.appBarStyle.alignment"
    case appBarBackground = "settings.appBarStyle.backgroundStyle"
    case appBarLiquidGlass = "settings.appBarStyle.liquidGlass"
    case appBarBackgroundFit = "settings.appBarStyle.backgroundFit"
    case appBarActiveIndicator = "settings.appBarStyle.activeIndicator"
    case appBarContent = "settings.appBarStyle.content"
    case appBarTitleCap = "settings.appBarStyle.titleCap"
    case appBarIconSource = "settings.appBarStyle.iconSource"
    case appBarGroupAdjacentWindows =
        "settings.appBarStyle.groupAdjacentWindows"
    case appBarThickness = "settings.appBarStyle.thickness"
    case appBarItemSizeAuto = "settings.appBarStyle.itemSize (auto)"
    case appBarItemSize = "settings.appBarStyle.itemSize"
    case appBarItemGap = "settings.appBarStyle.itemGap"
    case appBarFontSizeAuto = "settings.appBarStyle.fontSize (auto)"
    case appBarFontSize = "settings.appBarStyle.fontSize"
    case appBarCornerRoundness = "settings.appBarStyle.cornerRoundness"
    case appBarDimFactor = "settings.appBarStyle.dimFactor"
    case appBarFillColor = "settings.appBarStyle.fillColor"
    case appBarHighlightColor = "settings.appBarStyle.highlightColor"
    case appBarItemColor = "settings.appBarStyle.itemColor"
    case appBarActiveItemColor = "settings.appBarStyle.activeItemColor"
    case appBarHoverFillColor = "settings.appBarStyle.hoverFillColor"
    case appBarHoverItemColor = "settings.appBarStyle.hoverItemColor"
    case appBarGroupBadgeColor = "settings.appBarStyle.groupBadgeColor"
    case appBarGroupBadgeTextColor = "settings.appBarStyle.groupBadgeTextColor"
}

extension AppBarKey {
    var placement: SettingPlacement {
        switch self {
        case .appBarEdge:
            return .row(.bars, .appBar, .atRest)
        case .appBarAlignment, .appBarBackground, .appBarActiveIndicator,
            .appBarItemSizeAuto, .appBarItemGap, .appBarFontSizeAuto,
            .appBarCornerRoundness:
            return .row(.bars, .appBar, .showMore)
        case .appBarFontSize:
            return .row(
                .bars,
                .appBar,
                .showMore,
                gate: .setting(.appBar(.appBarFontSizeAuto))
            )
        case .appBarLiquidGlass:
            return .row(
                .bars,
                .appBar,
                .showMore,
                gate: .runtime(.liquidGlassUnavailable)
            )
        case .appBarBackgroundFit:
            return .row(
                .bars,
                .appBar,
                .showMore,
                gate: .setting(.appBar(.appBarBackground))
            )
        case .appBarContent:
            return .row(
                .bars,
                .appBar,
                .showMore,
                gate: .setting(.appBar(.appBarEdge))
            )
        case .appBarTitleCap:
            // Ungated (#937): accessibility label still announces title.
            return .row(
                .bars,
                .appBar,
                .showMore
            )
        case .appBarIconSource:
            return .row(
                .bars,
                .appBar,
                .showMore,
                gate: .setting(.appBar(.appBarContent)),
                exemptFromContainerGate: true
            )
        case .appBarItemSize:
            return .row(
                .bars,
                .appBar,
                .showMore,
                gate: .setting(.appBar(.appBarItemSizeAuto))
            )
        case .appBarGroupAdjacentWindows, .appBarThickness:
            return .row(.bars, .appBar, .atRest)
        case .appBarDimFactor:
            return .luaOnly
        case .appBarFillColor:
            return .row(.advancedColours, .appBar, .atRest)
        case .appBarHighlightColor:
            return .row(
                .advancedColours,
                .appBar,
                .atRest,
                gate: .setting(.appBar(.appBarActiveIndicator))
            )
        case .appBarItemColor, .appBarHoverFillColor,
            .appBarHoverItemColor, .appBarGroupBadgeColor,
            .appBarGroupBadgeTextColor:
            return .row(.advancedColours, .appBar, .showMore)
        case .appBarActiveItemColor:
            return .row(
                .advancedColours,
                .appBar,
                .showMore,
                gate: .setting(.appBar(.appBarActiveIndicator))
            )
        }
    }
}

extension AppBarKey {
    var text: SettingRowText {
        switch self {
        case .appBarEdge:
            return .text("app_bar.edge.label", help: "app_bar.edge.label.help")
        case .appBarAlignment:
            return .text(
                "app_bar.alignment.label",
                help: "app_bar.alignment.label.help"
            )
        case .appBarBackground:
            return .text("app_bar.background_style.label")
        case .appBarLiquidGlass:
            return .text(
                "app_bar.liquid_glass",
                help: "app_bar.liquid_glass.help"
            )
        case .appBarBackgroundFit:
            return .text("app_bar.background_fit.label")
        case .appBarActiveIndicator:
            return .text("app_bar.active_indicator.label")
        case .appBarContent:
            return .text("app_bar.content.label")
        case .appBarTitleCap:
            return .text(
                "app_bar.title_cap",
                help: "app_bar.title_cap.help"
            )
        case .appBarIconSource:
            return .text(
                "app_bar.icon_source.label",
                help: "app_bar.icon_source.help"
            )
        case .appBarGroupAdjacentWindows:
            return .text(
                "app_bar.group_adjacent",
                help: "app_bar.group_adjacent.help"
            )
        case .appBarThickness:
            return .text("app_bar.thickness")
        case .appBarItemSizeAuto:
            return .text("app_bar.item_size.auto")
        case .appBarItemSize:
            return .text("app_bar.item_size")
        case .appBarItemGap:
            return .text("app_bar.item_gap")
        case .appBarFontSizeAuto:
            return .text("app_bar.font_size.auto")
        case .appBarFontSize:
            return .text("app_bar.font_size")
        case .appBarCornerRoundness:
            return .text("app_bar.corner_roundness")
        case .appBarDimFactor:
            return .none
        case .appBarFillColor:
            return .text("app_bar.color.fill")
        case .appBarHighlightColor:
            return .text("app_bar.color.highlight")
        case .appBarItemColor:
            return .text("app_bar.color.item")
        case .appBarActiveItemColor:
            return .text("app_bar.color.active_item")
        case .appBarHoverFillColor:
            return .text("app_bar.color.hover_fill")
        case .appBarHoverItemColor:
            return .text("app_bar.color.hover_item")
        case .appBarGroupBadgeColor:
            return .text("app_bar.color.group_badge")
        case .appBarGroupBadgeTextColor:
            return .text("app_bar.color.badge_text")
        }
    }
}
