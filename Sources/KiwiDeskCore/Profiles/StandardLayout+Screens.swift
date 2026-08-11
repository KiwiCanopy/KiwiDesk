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

    /// The layout mode `space` opens in.
    ///
    /// Where the sparse map says nothing, the answer is **the
    /// screen's own best layout** — not a fixed `bsp` (owner
    /// ruling, 2026-08-11). The workflow presets predate the
    /// screen-shape theory and several are sparse: applying
    /// `Minimalist` or `Focus Stack` on a laptop silently handed
    /// it a BSP space, which is the one layout `ScreenClass`
    /// rules out there — at 1728 pt a three-window BSP is already
    /// under the minimum in one axis.
    ///
    /// `shape` is nil where the caller genuinely cannot know: a
    /// preset card draws a plan for a screen COUNT, not for the
    /// hardware in front of you, and a three-screen preset is
    /// drawn on a one-screen Mac. Then the historic `bsp` stands,
    /// because inventing a shape would be a worse answer than the
    /// old one.
    public func mode(
        of space: SpaceID,
        on shape: ScreenClass?
    ) -> LayoutMode {
        if let declared = spaceModes[space] { return declared }
        return shape?.layouts.first ?? .bsp
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
    /// `shape` nil draws the plan as a plan — see `mode(of:on:)`.
    public func openingMode(
        onScreen position: Int,
        screens: Int,
        on shape: ScreenClass? = nil
    ) -> LayoutMode? {
        spaces(onScreen: position, screens: screens)
            .first
            .map { mode(of: $0, on: shape) }
    }
}
