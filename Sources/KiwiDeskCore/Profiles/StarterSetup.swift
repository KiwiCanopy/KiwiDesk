import CoreGraphics
import Foundation

/// Default profile generator for fresh installs and Starter presets
/// (#678 Phase 4 pass 11, turn 15b, #466, `docs/design-decisions.md`,
/// `.claude/rules/parity-tests.md`).
public enum StarterSetup {
    /// Canonical profile name string (#485).
    public static let name = "Starter"

    /// Nominal desktop size used for headless or display-less environments.
    static let nominalDesktop = CGSize(width: 2560, height: 1440)

    /// Ensures at least one display size is present.
    static func floored(_ sizes: [CGSize]) -> [CGSize] {
        sizes.isEmpty ? [nominalDesktop] : sizes
    }

    /// Screen sizes in positional display order.
    public static func sizes(
        displays: [Display],
        mainID: DisplayID?
    ) -> [CGSize] {
        floored(
            PositionalDisplays.ordered(displays, mainID: mainID)
                .map(\.frame.size)
        )
    }

    /// Space slot description with assigned display index and layout mode.
    struct Slot: Equatable {
        let number: Int
        let screen: Int
        let mode: LayoutMode
    }

    /// THE one walk (review 2026-08-11): space numbering was once
    /// written twice, and the two had to agree or a space took its
    /// mode from one screen and its pin from another, silently.
    /// Every map below derives from this.
    static func slots(_ sizes: [CGSize]) -> [Slot] {
        var slots: [Slot] = []
        var number = 1
        let blocks = StarterAllocation.modes(sizes: floored(sizes))
        for (screen, modes) in blocks.enumerated() {
            for mode in modes {
                slots.append(
                    Slot(number: number, screen: screen, mode: mode)
                )
                number += 1
            }
        }
        return slots
    }

    /// Total spaces for these screens.
    public static func spaceCount(sizes: [CGSize]) -> Int {
        slots(sizes).count
    }

    /// List of space IDs in positional order.
    public static func spaces(sizes: [CGSize]) -> [SpaceID] {
        (1...max(1, spaceCount(sizes: sizes))).map { SpaceID($0) }
    }

    /// A mode for EVERY space, never a sparse diff against the
    /// fallback: each layout was chosen for its screen, so a
    /// changed global fallback must not silently move one.
    public static func spaceModes(
        sizes: [CGSize]
    ) -> [SpaceID: LayoutMode] {
        var modes: [SpaceID: LayoutMode] = [:]
        for slot in slots(sizes) {
            modes[SpaceID(slot.number)] = slot.mode
        }
        return modes
    }

    /// Positional secondary screen assignment (unlisted ⇒ main).
    /// Not re-derivable by arithmetic — the blocks are unequal, so
    /// there is no `(n - 1) / 5`; anything needing a space's
    /// screen reads this map.
    public static func spaceScreens(
        sizes: [CGSize]
    ) -> [SpaceID: Int] {
        var screens: [SpaceID: Int] = [:]
        for slot in slots(sizes) where slot.screen >= 1 {
            screens[SpaceID(slot.number)] = slot.screen
        }
        return screens
    }

    /// The class of the screen each layout first lands on; the
    /// tuning reads a single-screen layout's from here (#1662).
    static func hosts(_ sizes: [CGSize]) -> [LayoutMode: ScreenClass] {
        let sizes = floored(sizes)
        var hosts: [LayoutMode: ScreenClass] = [:]
        for slot in slots(sizes) where hosts[slot.mode] == nil {
            hosts[slot.mode] = ScreenClass.of(sizes[slot.screen])
        }
        return hosts
    }

    /// The starter's ONE per-space override (#1662): Scrolling on a
    /// portrait screen that is not the main one scrolls vertically,
    /// where every other Scrolling space takes the main's direction.
    static func scrollingOverrides(
        _ sizes: [CGSize]
    ) -> [SpaceID: ScrollingOverride] {
        let sizes = floored(sizes)
        guard ScreenClass.of(sizes[0]) != .pivoted else { return [:] }
        var overrides: [SpaceID: ScrollingOverride] = [:]
        for slot in slots(sizes)
        where slot.mode == .scrolling && slot.screen > 0
            && ScreenClass.of(sizes[slot.screen]) == .pivoted
        {
            var vertical = ScrollingOverride()
            vertical.orientation = .vertical
            overrides[SpaceID(slot.number)] = vertical
        }
        return overrides
    }

    /// The tuning for these screens, overrides included.
    static func settings(sizes: [CGSize]) -> TilingSettings {
        let sizes = floored(sizes)
        var settings = StarterTuning.settings(
            mainShape: ScreenClass.of(sizes[0]),
            hosts: hosts(sizes)
        )
        settings.scrolling.override = scrollingOverrides(sizes)
        return settings
    }

    /// Starter setup packaged as a `StandardLayout` model.
    public static func standardLayout(
        sizes: [CGSize]
    ) -> StandardLayout {
        let sizes = floored(sizes)
        var layout = StandardLayout(
            name: name,
            screenCount: sizes.count,
            spaceCount: spaceCount(sizes: sizes),
            spaceModes: spaceModes(sizes: sizes),
            spaceScreens: spaceScreens(sizes: sizes),
            isStandard: false,
            settings: settings(sizes: sizes)
        )
        layout.starterTitle = StarterTitle(
            shape: ScreenClass.of(sizes[0]),
            otherScreens: sizes.count - 1
        )
        return layout
    }

    /// Constructs standard layout from live display collection.
    public static func standardLayout(
        displays: [Display],
        mainID: DisplayID?
    ) -> StandardLayout {
        standardLayout(
            sizes: sizes(displays: displays, mainID: mainID)
        )
    }
}
