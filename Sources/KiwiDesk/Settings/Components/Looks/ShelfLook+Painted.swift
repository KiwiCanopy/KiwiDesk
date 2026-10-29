import KiwiDeskCore

extension ShelfLook {
    /// `settings` with this look painted on, its colors included:
    /// what a click gives, which a tile and Simple's preview draw.
    func painted(over settings: TilingSettings) -> TilingSettings {
        var painted = settings
        apply(to: &painted)
        return painted
    }
}
