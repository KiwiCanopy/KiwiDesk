import KiwiDeskCore

/// Per-layout App Bar census slice (`LayoutAppBar`, Monocle and
/// Scrolling): how each layout shows its bar (#761) — drawn in the
/// KiwiShelf card — and its Lua-only overrides of the bar's OWN
/// fields; the shelf's fields have none (#1517).

enum LayoutAppBarKey: String, CaseIterable, Hashable {
    case monocleAppBarVisibility = "settings.monocle.appBar.visibility"
    case monocleAppBarActiveIndicator =
        "settings.monocle.appBar.activeIndicator"
    case monocleAppBarTitleCap = "settings.monocle.appBar.titleCap"
    case monocleAppBarGroupAdjacentWindows =
        "settings.monocle.appBar.groupAdjacentWindows"
    case scrollingAppBarVisibility =
        "settings.scrolling.appBar.visibility"
    case scrollingAppBarActiveIndicator =
        "settings.scrolling.appBar.activeIndicator"
    case scrollingAppBarTitleCap = "settings.scrolling.appBar.titleCap"
    case scrollingAppBarGroupAdjacentWindows =
        "settings.scrolling.appBar.groupAdjacentWindows"
}

extension LayoutAppBarKey {
    var placement: SettingPlacement {
        switch self {
        case .monocleAppBarVisibility, .scrollingAppBarVisibility:
            // Drawn in the KiwiShelf card's Show group, which has
            // no container gate.
            return .row(.bars, .kiwishelf, .atRest)
        case .monocleAppBarActiveIndicator,
            .monocleAppBarTitleCap, .monocleAppBarGroupAdjacentWindows,
            .scrollingAppBarActiveIndicator,
            .scrollingAppBarTitleCap,
            .scrollingAppBarGroupAdjacentWindows:
            return .luaOnly
        }
    }
}

extension LayoutAppBarKey {
    var text: SettingRowText {
        switch self {
        case .monocleAppBarVisibility:
            return .text("kiwishelf.show.monocle")
        case .scrollingAppBarVisibility:
            return .text("kiwishelf.show.scrolling")
        case .monocleAppBarActiveIndicator,
            .monocleAppBarTitleCap, .monocleAppBarGroupAdjacentWindows,
            .scrollingAppBarActiveIndicator,
            .scrollingAppBarTitleCap,
            .scrollingAppBarGroupAdjacentWindows:
            return .none
        }
    }
}

extension SettingKey {
    /// The layout a row's label names at `%1$@` (#818, Family
    /// B) — the same argument its catalog control interpolates
    /// (`SettingsControl(naming:)`), so the census label, the
    /// search row and the diff row read one sentence.
    var labelMode: LayoutMode? {
        switch self {
        case .layoutAppBar(.monocleAppBarVisibility): return .monocle
        case .layoutAppBar(.scrollingAppBarVisibility): return .scrolling
        default: return nil
        }
    }
}
