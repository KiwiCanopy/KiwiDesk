import Foundation

/// Standard layout plan accessors and screen assignments
/// (`ProfileComposition.compose`, `gui.md`, #678 turn 13a).
extension StandardLayout {
    /// Every space defined in plan order ("1"..."N").
    public var plannedSpaces: [SpaceID] {
        guard spaceCount > 0 else { return [] }
        return (1...spaceCount).map { SpaceID($0) }
    }

    /// Layout mode for space. Where the sparse map says nothing,
    /// the answer is the SCREEN's own best layout, not a fixed
    /// `bsp` (owner ruling 2026-08-11): sparse presets on a laptop
    /// silently handed it BSP, the one layout `ScreenClass` rules
    /// out there. `shape` nil (a preset card drawn for a screen
    /// COUNT) keeps the historic `bsp`.
    public func mode(
        of space: SpaceID,
        on shape: ScreenClass?
    ) -> LayoutMode {
        if let declared = spaceModes[space] { return declared }
        return shape?.layouts.first ?? .bsp
    }

    /// Positional screen index for space, clamped to screen count bounds.
    public func screen(
        of space: SpaceID,
        screens: Int
    ) -> Int {
        guard screens > 0 else { return 0 }
        return min(max(spaceScreens[space] ?? 0, 0), screens - 1)
    }

    /// Spaces planned for positional screen in plan order.
    public func spaces(
        onScreen position: Int,
        screens: Int
    ) -> [SpaceID] {
        plannedSpaces.filter {
            screen(of: $0, screens: screens) == position
        }
    }

    /// Mode of first space opening on positional screen index (`ScreenClass`).
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
