import Foundation

/// A `StandardLayout`'s plan, read the one way (#678 turn 13a).
///
/// `spaceScreens` and `spaceModes` are both **sparse** — an
/// unlisted space sits on the main display, and an unlisted mode
/// is `bsp`. Those two fallbacks are the layout's semantics, not
/// the composer's implementation detail, so they live here and
/// `ProfileComposition.compose` reads them rather than restating
/// them. The Settings preset card reads the same accessors: a
/// preview that claims engine behavior asks the engine
/// (`.claude/rules/gui.md`), and before this existed the card had
/// its own copy of both fallbacks with nothing holding the two
/// equal.
extension StandardLayout {
    /// Every space the layout defines, in plan order ("1"…"N").
    public var plannedSpaces: [SpaceID] {
        guard spaceCount > 0 else { return [] }
        return (1...spaceCount).map { SpaceID($0) }
    }

    /// The layout mode `space` opens in — `bsp` where the sparse
    /// map says nothing.
    public func mode(of space: SpaceID) -> LayoutMode {
        spaceModes[space] ?? .bsp
    }

    /// The positional screen `space` plans for (0 = main, 1 = the
    /// next secondary, …), clamped into `screens`.
    ///
    /// The clamp is defensive on both ends: a Standard never
    /// plans beyond its own screen count, and a hand-edited one
    /// must not index off either end of the display list.
    public func screen(
        of space: SpaceID,
        screens: Int
    ) -> Int {
        guard screens > 0 else { return 0 }
        return min(max(spaceScreens[space] ?? 0, 0), screens - 1)
    }

    /// The spaces planned for positional screen `position`, in
    /// plan order, over a setup of `screens` displays.
    public func spaces(
        onScreen position: Int,
        screens: Int
    ) -> [SpaceID] {
        plannedSpaces.filter {
            screen(of: $0, screens: screens) == position
        }
    }

    /// The mode the FIRST space on `position` opens in — what
    /// that screen shows when the layout applies — or nil when
    /// the layout plans nothing for it.
    public func openingMode(
        onScreen position: Int,
        screens: Int
    ) -> LayoutMode? {
        spaces(onScreen: position, screens: screens)
            .first
            .map { mode(of: $0) }
    }
}
