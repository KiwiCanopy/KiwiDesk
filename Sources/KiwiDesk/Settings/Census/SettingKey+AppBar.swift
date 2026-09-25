/// The global App Bar (`AppBarStyle`) slice of the census. Its
/// colours, symbol style and dim are the shelf's (#1517).

enum AppBarKey: String, CaseIterable, Hashable {
    case appBarActiveIndicator = "settings.appBarStyle.activeIndicator"
    case appBarContent = "settings.appBarStyle.content"
    case appBarTitleCap = "settings.appBarStyle.titleCap"
    case appBarGroupAdjacentWindows =
        "settings.appBarStyle.groupAdjacentWindows"
}

extension AppBarKey {
    var placement: SettingPlacement {
        switch self {
        case .appBarActiveIndicator, .appBarGroupAdjacentWindows:
            return .row(.bars, .appBar, .atRest)
        case .appBarContent:
            return .row(
                .bars,
                .appBar,
                .atRest,
                gate: .setting(.kiwishelf(.edge))
            )
        case .appBarTitleCap:
            // Ungated (#937): accessibility label still announces title.
            return .row(.bars, .appBar, .atRest)
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
        case .appBarGroupAdjacentWindows:
            return .text(
                "app_bar.group_adjacent",
                help: "app_bar.group_adjacent.help"
            )
        }
    }
}
