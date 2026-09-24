import KiwiDeskCore

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
    case scrollingAppBarEnabled = "settings.scrolling.appBar.enabled"
    case scrollingAppBarActiveIndicator =
        "settings.scrolling.appBar.activeIndicator"
    case scrollingAppBarContent = "settings.scrolling.appBar.content"
    case scrollingAppBarTitleCap = "settings.scrolling.appBar.titleCap"
    case scrollingAppBarGroupAdjacentWindows =
        "settings.scrolling.appBar.groupAdjacentWindows"
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
            .scrollingAppBarActiveIndicator, .scrollingAppBarContent,
            .scrollingAppBarTitleCap,
            .scrollingAppBarGroupAdjacentWindows:
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
            .scrollingAppBarActiveIndicator, .scrollingAppBarContent,
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
        case .layoutAppBar(.monocleAppBarEnabled): return .monocle
        case .layoutAppBar(.scrollingAppBarEnabled): return .scrolling
        default: return nil
        }
    }
}
