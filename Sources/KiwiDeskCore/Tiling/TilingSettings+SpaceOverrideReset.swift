import Foundation

/// Per-space layout override inspection and reset operations
/// (#290). The `LayoutMode` switches are exhaustive, so a new
/// layout is a compile error until handled — forget-proof
/// without a hand-mirrored parity test.
extension TilingSettings {
    /// Overridable layouts excluding floating mode (`LayoutMode.allCases`).
    static var overridableLayouts: [LayoutMode] {
        LayoutMode.allCases.filter { $0 != .floating }
    }

    /// Returns saved layout override for space and mode, or nil if inherited.
    public func layoutOverride(
        _ mode: LayoutMode,
        for space: SpaceID
    ) -> (any SpaceLayoutOverride)? {
        switch mode {
        case .bsp: return bsp.override[space]
        case .stack: return stack.override[space]
        case .scrolling: return scrolling.override[space]
        case .grid: return grid.override[space]
        case .monocle: return monocle.override[space]
        case .track: return track.override[space]
        case .floating: return nil
        }
    }

    /// Count of explicitly overridden fields for space under mode (#290).
    public func overrideFieldCount(
        _ mode: LayoutMode,
        for space: SpaceID
    ) -> Int {
        layoutOverride(mode, for: space)?.fieldCount ?? 0
    }

    /// Total count of set override fields across all layouts for space (#290).
    public func overrideFieldCount(for space: SpaceID) -> Int {
        Self.overridableLayouts.reduce(0) {
            $0 + overrideFieldCount($1, for: space)
        }
    }

    /// Dormant layout overrides for inactive layouts on space (#290).
    public func dormantOverrides(
        for space: SpaceID,
        active: LayoutMode
    ) -> [(mode: LayoutMode, count: Int)] {
        Self.overridableLayouts.compactMap { mode in
            guard mode != active else { return nil }
            let count = overrideFieldCount(mode, for: space)
            return count > 0 ? (mode, count) : nil
        }
    }

    /// Resets layout override for space under mode.
    public mutating func resetOverride(
        _ mode: LayoutMode,
        for space: SpaceID
    ) {
        switch mode {
        case .bsp: bsp.override[space] = nil
        case .stack: stack.override[space] = nil
        case .scrolling: scrolling.override[space] = nil
        case .grid: grid.override[space] = nil
        case .monocle: monocle.override[space] = nil
        case .track: track.override[space] = nil
        case .floating: break
        }
    }

    /// Resets all layout overrides for space, leaving non-layout
    /// settings (#290).
    public mutating func resetAllLayoutOverrides(
        for space: SpaceID
    ) {
        for mode in Self.overridableLayouts {
            resetOverride(mode, for: space)
        }
    }
}
