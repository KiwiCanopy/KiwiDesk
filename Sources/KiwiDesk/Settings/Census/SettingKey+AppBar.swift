/// The global App Bar (`AppBarStyle`) slice of the census.

enum AppBarKey: String, CaseIterable, Hashable {
    case appBarActiveIndicator = "settings.appBarStyle.activeIndicator"
    case appBarContent = "settings.appBarStyle.content"
    case appBarTitleCap = "settings.appBarStyle.titleCap"
    case appBarIconSource = "settings.appBarStyle.iconSource"
    case appBarGroupAdjacentWindows =
        "settings.appBarStyle.groupAdjacentWindows"
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
        case .appBarActiveIndicator:
            return .row(.bars, .appBar, .showMore)
        case .appBarContent:
            return .row(
                .bars,
                .appBar,
                .showMore,
                gate: .setting(.kiwishelf(.edge))
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
        case .appBarGroupAdjacentWindows:
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
