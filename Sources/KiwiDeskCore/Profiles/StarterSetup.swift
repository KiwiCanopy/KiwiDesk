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

    /// Generates space slots from screen sizes (review 2026-08-11).
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

    /// Explicit layout mode mapping per space.
    public static func spaceModes(
        sizes: [CGSize]
    ) -> [SpaceID: LayoutMode] {
        var modes: [SpaceID: LayoutMode] = [:]
        for slot in slots(sizes) {
            modes[SpaceID(slot.number)] = slot.mode
        }
        return modes
    }

    /// Positional secondary screen assignment mapping (omits main screen
    /// index 0).
    public static func spaceScreens(
        sizes: [CGSize]
    ) -> [SpaceID: Int] {
        var screens: [SpaceID: Int] = [:]
        for slot in slots(sizes) where slot.screen >= 1 {
            screens[SpaceID(slot.number)] = slot.screen
        }
        return screens
    }

    /// Starter setup packaged as a `StandardLayout` model.
    public static func standardLayout(
        sizes: [CGSize]
    ) -> StandardLayout {
        let sizes = floored(sizes)
        return StandardLayout(
            name: name,
            screenCount: sizes.count,
            spaceCount: spaceCount(sizes: sizes),
            spaceModes: spaceModes(sizes: sizes),
            spaceScreens: spaceScreens(sizes: sizes),
            isStandard: false,
            settings: StarterTuning.settings(
                mainShape: ScreenClass.of(sizes[0])
            )
        )
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
