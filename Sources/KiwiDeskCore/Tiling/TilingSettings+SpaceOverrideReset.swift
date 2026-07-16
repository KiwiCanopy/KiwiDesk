import Foundation

/// Per-space *layout* override inspection and reset (#290). These
/// scope strictly to the six per-layout override maps — the ones
/// the Customize popover edits — and deliberately leave the other
/// per-space settings (gap, placement, icon, pin, roles) alone.
/// `removeSpace` is the whole-space wipe; this is the "reset the
/// layout overrides" surface the editor's reset buttons need.
///
/// The `LayoutMode` switches are exhaustive, so adding a layout
/// forces every helper here to handle it (a new enum case is a
/// compile error), keeping the map list forget-proof without a
/// hand-mirrored parity test.
extension TilingSettings {
    /// The layouts that own a per-space override map — every mode
    /// but Floating (the one mode whose `layoutOverride` switch
    /// returns nil). Derived from `allCases`, so a new layout is
    /// covered automatically. This is the single source for both
    /// the `Overrides (N)` count and the dormant list, so the two
    /// can't range over different sets; the GUI reads the ordered
    /// list back through `dormantOverrides` rather than re-deriving
    /// its own layout list.
    static var overridableLayouts: [LayoutMode] {
        LayoutMode.allCases.filter { $0 != .floating }
    }

    /// The saved override for `space` under `mode`, or nil when
    /// the space inherits everything (or `mode` is Floating, which
    /// has no layout overrides). Existential so callers can read
    /// `fieldCount` without knowing the concrete family.
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

    /// Set override fields for `space` under `mode` — 0 when it
    /// inherits everything. Drives the dormant-layout disclosure's
    /// per-layout count (#290).
    public func overrideFieldCount(
        _ mode: LayoutMode,
        for space: SpaceID
    ) -> Int {
        layoutOverride(mode, for: space)?.fieldCount ?? 0
    }

    /// Total set override fields across every layout for `space` —
    /// the `Overrides…` button's count, including layouts that are
    /// not the space's active one (#290).
    public func overrideFieldCount(for space: SpaceID) -> Int {
        Self.overridableLayouts.reduce(0) {
            $0 + overrideFieldCount($1, for: space)
        }
    }

    /// The layouts (other than `active`) that carry saved
    /// overrides for `space`, each with its set-field count — the
    /// dormant-layout disclosure's contents, and (empty or not)
    /// the gate for it and the `Reset All Layout Overrides` button
    /// (#290). Ordered by `overridableLayouts` — the same list the
    /// count sums, so a layout can never be counted yet missing
    /// from this list. The GUI renders it directly instead of
    /// re-deriving a layout list of its own.
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

    /// Clears `space`'s override for one layout. A no-op for
    /// Floating and for a space that already inherits.
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

    /// Clears `space`'s override for every layout — the destructive
    /// `Reset All Layout Overrides` (#290). Leaves gap, placement,
    /// icon, and pin overrides intact (those are not layout
    /// overrides and the popover never edits them).
    public mutating func resetAllLayoutOverrides(
        for space: SpaceID
    ) {
        for mode in Self.overridableLayouts {
            resetOverride(mode, for: space)
        }
    }
}
