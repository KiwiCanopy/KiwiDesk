/// The global App Bar (`AppBarStyle`) slice of the census. Its
/// colours, glyph style and dim are the shelf's (#1517).

enum AppBarKey: String, CaseIterable, Hashable {
    case appBarActiveIndicator = "settings.appBarStyle.activeIndicator"
    case appBarTitleCap = "settings.appBarStyle.titleCap"
    case appBarGroupAdjacentWindows =
        "settings.appBarStyle.groupAdjacentWindows"
    case appBarReserve = "settings.appBarStyle.reserve"
}

extension AppBarKey {
    var placement: SettingPlacement {
        switch self {
        case .appBarActiveIndicator, .appBarGroupAdjacentWindows:
            return .row(.bars, .appBar, .atRest)
        case .appBarTitleCap:
            // Ungated (#937): accessibility label still announces title.
            return .row(.bars, .appBar, .atRest)
        case .appBarReserve:
            // Lua/CLI only by ruling (#1524).
            return .luaOnly
        }
    }
}

extension AppBarKey {
    var text: SettingRowText {
        switch self {
        case .appBarActiveIndicator:
            return .text("app_bar.active_indicator.label")
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
        case .appBarReserve:
            return .none
        }
    }
}
