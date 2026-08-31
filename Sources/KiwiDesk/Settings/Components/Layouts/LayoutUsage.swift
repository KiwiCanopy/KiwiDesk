import KiwiDeskCore

/// Layout usage queries across configured spaces — ONE answer for
/// the page's three surfaces (strip counts, spaces-using card,
/// landing layout), which disagreed on the unrecorded-space
/// default while they were three copies.
enum LayoutUsage {
    /// Returns profile spaces using mode, defaulting unrecorded spaces
    /// to .bsp.
    static func spaces(
        on mode: LayoutMode,
        in config: GuiConfig
    ) -> [SpaceID] {
        config.spaces.filter {
            (config.spaceModes[$0] ?? .bsp) == mode
        }
    }

    /// The layout the page opens on: the profile's most-used
    /// tuned layout, falling back to BSP. Floating never wins —
    /// it has nothing to tune and so has no tile.
    static func mostUsed(in config: GuiConfig) -> LayoutMode {
        let counts = LayoutMode.placementTabs.map {
            ($0, spaces(on: $0, in: config).count)
        }
        return counts.max { $0.1 < $1.1 }
            .flatMap { $0.1 > 0 ? $0.0 : nil } ?? .bsp
    }
}
