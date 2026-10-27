import KiwiDeskCore

/// Where each Colors & glass row's hex is stored, for the
/// writers that act on rows by key rather than by builder — the
/// role groups' colour (#1857). `ColorsAndGlassPathsTests` holds
/// that every colour row resolves to its own palette colour.
enum ColorsAndGlassPaths {
    static func hex(
        _ key: SettingKey
    ) -> WritableKeyPath<TilingSettings, String>? {
        switch key {
        case .kiwishelf(.fillColor): return \.kiwishelf.fillColor
        case .kiwishelf(.itemColor): return \.kiwishelf.itemColor
        case .kiwishelf(.activeItemColor):
            return \.kiwishelf.activeItemColor
        case .kiwishelf(.highlightColor):
            return \.kiwishelf.highlightColor
        case .kiwishelf(.hoverFillColor):
            return \.kiwishelf.hoverFillColor
        case .kiwishelf(.hoverItemColor):
            return \.kiwishelf.hoverItemColor
        case .kiwishelf(.groupBadgeColor):
            return \.kiwishelf.groupBadgeColor
        case .kiwishelf(.groupBadgeTextColor):
            return \.kiwishelf.groupBadgeTextColor
        case .kiwishelf(.borderColor): return \.kiwishelf.borderColor
        case .spaceBar(.spaceBarFocusedItemColor):
            return \.spaceBarStyle.focusedItemColor
        case .spaceBar(.spaceBarFocusedHighlightColor):
            return \.spaceBarStyle.focusedHighlightColor
        case .borders(.borderFocusedColor):
            return \.borderStyle.focusedColor
        case .borders(.borderUnfocusedColor):
            return \.borderStyle.unfocusedColor
        case .borders(.stickyColor): return \.stickyStyle.color
        case .borders(.floatingColor): return \.floatingStyle.color
        case .borders(.pocketColor): return \.pocketStyle.color
        case .borders(.dragGhostBorderColor):
            return \.dragGhost.borderColor
        case .borders(.dragGhostFillColor): return \.dragGhost.fillColor
        case .borders(.dragDropZoneBorderColor):
            return \.dragDropZone.borderColor
        case .borders(.dragDropZoneFillColor):
            return \.dragDropZone.fillColor
        default: return nil
        }
    }
}
