import KiwiDeskCore

/// Which spaces run which layout — the one answer three
/// surfaces on this page need: the strip's per-tile count, the
/// spaces-using card's list, and the landing layout the page
/// opens on.
///
/// It is one function because the three disagreed while it was
/// three: two read `config.spaces` and defaulted an unrecorded
/// space to `.bsp` (the reading every other surface in the app
/// uses), while the landing counted `spaceModes.values` alone —
/// so a profile of untouched spaces plus one Grid space landed
/// the reader on Grid while the strip beside them said BSP had
/// the spaces.
enum LayoutUsage {
    /// The profile's spaces on `mode`, in the user's own order.
    /// A space with no recorded mode runs the default.
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
