import KiwiDeskCore

/// Which catalog child a colour row lands a search on (#2389,
/// #1250): one arm per row the Colors drawer draws, named
/// outright so the catalog's site guards see each declaration
/// referenced. The Fill is at rest and takes none (#277, #2593).
enum ColorsAndGlassAnchors {
    private static var rows: ColorsDrawerControls {
        SettingsCatalog.colors.colorsDrawer.children
    }

    static func control(for key: SettingKey) -> SettingsControl? {
        switch key {
        case .kiwishelf(let k): return shelf(k)
        case .spaceBar(.spaceBarFocusedItemColor):
            return rows.tintFocusedWindow
        case .spaceBar(.spaceBarFocusedHighlightColor):
            return rows.tintFrontAppIndicator
        case .borders(let k): return borders(k)
        default: return nil
        }
    }

    private static func shelf(_ key: KiwiShelfKey) -> SettingsControl? {
        switch key {
        case .activeItemColor: return rows.tintActiveItem
        case .highlightColor: return rows.tintHighlight
        case .hoverFillColor: return rows.tintHoverFill
        case .itemColor: return rows.tintShelfItem
        case .hoverItemColor: return rows.tintShelfHoverItem
        case .borderColor: return rows.tintShelfBorder
        case .groupBadgeColor: return rows.tintGroupBadge
        case .groupBadgeTextColor: return rows.tintBadgeText
        default: return nil
        }
    }

    private static func borders(_ key: BordersKey) -> SettingsControl? {
        switch key {
        case .borderFocusedColor: return rows.tintFocusBorder
        case .borderUnfocusedColor: return rows.tintUnfocusedBorder
        case .stickyColor: return rows.tintStickyMark
        case .floatingColor: return rows.tintFloatingMark
        case .pocketColor: return rows.tintPocketMark
        default: return nil
        }
    }
}
