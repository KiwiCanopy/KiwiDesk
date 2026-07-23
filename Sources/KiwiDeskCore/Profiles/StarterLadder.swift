import Foundation

/// The beginner "ladder" seeded on a fresh install (#466): five
/// spaces per display, each demoing a different layout mode so a
/// newcomer meets the whole range at once. The block repeats
/// per display — spaces 1–5 on the main, 6–10 on the second, …
///
/// | Position in block | Mode | Shown off |
/// |---|---|---|
/// | 1 | track | new window → its own new track |
/// | 2 | stack | single master, 80/20 split |
/// | 3 | bsp | the default binary layout |
/// | 4 | grid | a 3×2 grid |
/// | 5 | floating | untiled |
///
/// One pure generator behind BOTH callers — the first-run seed
/// (arbitrary live display count) and the fixed 1/2/3-screen
/// `StandardLayout` presets — so the ladder is defined once, not
/// hand-mirrored (`.claude/rules/parity-tests.md`, at the logic
/// level).
public enum StarterLadder {
    /// Spaces each display's block contributes.
    public static let spacesPerDisplay = 5

    /// The mode for each 1-based position within a block; `.bsp`
    /// is the array-index-2 rung and, being the fallback, is
    /// omitted from the sparse `spaceModes` map below.
    private static let blockModes: [LayoutMode] = [
        .track, .stack, .bsp, .grid, .floating,
    ]

    /// Total spaces for `displayCount` displays (floored at one —
    /// a machine always drives at least one screen).
    public static func spaceCount(displayCount: Int) -> Int {
        max(1, displayCount) * spacesPerDisplay
    }

    /// The ladder's spaces, ids `"1"`…`"5N"`, in display order.
    public static func spaces(displayCount: Int) -> [SpaceID] {
        (1...spaceCount(displayCount: displayCount))
            .map { SpaceID($0) }
    }

    /// Sparse per-space modes — `.bsp` positions are omitted (they
    /// resolve to the fallback), matching `StandardLayout`'s
    /// sparse convention.
    public static func spaceModes(
        displayCount: Int
    ) -> [SpaceID: LayoutMode] {
        var modes: [SpaceID: LayoutMode] = [:]
        for number in 1...spaceCount(displayCount: displayCount) {
            let mode = blockModes[(number - 1) % spacesPerDisplay]
            if mode != .bsp { modes[SpaceID(number)] = mode }
        }
        return modes
    }

    /// Sparse positional screen per space (0 = main). Main-display
    /// spaces are omitted (unlisted ⇒ main), so only the second
    /// display's block onward is named.
    public static func spaceScreens(
        displayCount: Int
    ) -> [SpaceID: Int] {
        var screens: [SpaceID: Int] = [:]
        for number in 1...spaceCount(displayCount: displayCount) {
            let screen = (number - 1) / spacesPerDisplay
            if screen >= 1 { screens[SpaceID(number)] = screen }
        }
        return screens
    }

    /// The positional display index a space's block sits on
    /// (0 = main) — the seed's `spaceScreens` twin for live pins.
    public static func screen(of space: SpaceID) -> Int {
        guard let number = Int(space.raw) else { return 0 }
        return (number - 1) / spacesPerDisplay
    }

    /// The beginner tuning the ladder ships with: a comfortable
    /// gap, the stack's single-master 80/20 split, and track's
    /// new-window-opens-its-own-track. Grid's 3×2 is already the
    /// default, so it needs no override here.
    public static func settings(gap: Double = 8) -> TilingSettings {
        var settings = TilingSettings()
        settings.gapsGlobal = .uniform(gap)
        settings.stack.masterRatio = 0.8
        settings.track.newWindow = .ownTrack
        return settings
    }

    /// The ladder packaged as a `StandardLayout` for a display
    /// count — the single shape shared by the fixed 1/2/3-screen
    /// presets (which pass a `summary`) and the first-run seed
    /// (which composes and applies it through `applyStandard`, so
    /// the seed rides the one canonical apply path rather than
    /// re-implementing it).
    public static func standardLayout(
        displayCount: Int,
        summary: String = ""
    ) -> StandardLayout {
        StandardLayout(
            name: "Starter",
            summary: summary,
            screenCount: max(1, displayCount),
            spaceCount: spaceCount(displayCount: displayCount),
            spaceModes: spaceModes(displayCount: displayCount),
            spaceScreens: spaceScreens(displayCount: displayCount),
            isStandard: false,
            settings: settings()
        )
    }
}
