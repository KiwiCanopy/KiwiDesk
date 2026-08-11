import CoreGraphics
import Foundation

/// The setup a fresh install gets: spaces chosen for the screens
/// that are actually connected (#678 Phase 4 pass 11, turn 15b).
///
/// This supersedes the beginner *ladder* (#466), which gave every
/// display the same five spaces — one per layout mode — to demo
/// the whole range. The theory changed: approachable by default
/// means a setup you KEEP, not a showroom, so a laptop is no
/// longer handed Track and a 27" is no longer handed Monocle. The
/// argument is in `docs/design-decisions.md`; the name "Starter"
/// stayed because it is user-visible and still true.
///
/// Three collaborators, one each: `ScreenClass` says what a screen
/// is and which layouts it wants, `StarterAllocation` says how
/// many each gets, and `StarterTuning` says how the layouts are
/// tuned. This assembles them into the space list, the mode map
/// and the pins.
///
/// One generator behind BOTH callers — the first-run seed and the
/// `Starter` presets — so the two cannot drift
/// (`.claude/rules/parity-tests.md`, at the logic level). Both now
/// pass the live screens, the presets included: a preset that
/// planned for "two screens" in the abstract could not answer
/// which two.
public enum StarterSetup {
    /// The canonical profile name, shared by its `StandardLayout`
    /// face and the monitor-change baseline predicate (#485) —
    /// one string, never a magic literal.
    public static let name = "Starter"

    /// What a screen-less read is treated as. A headless CI run
    /// and a first launch before `publishDisplays` both reach
    /// here, and a setup for no screens at all is not a thing
    /// that can be built — so they get the middle class, which is
    /// the one whose layouts suit the widest range of hardware.
    static let nominalDesktop = CGSize(width: 2560, height: 1440)

    /// Sizes floored at one screen, so every entry point below
    /// shares the same answer for an empty read.
    static func floored(_ sizes: [CGSize]) -> [CGSize] {
        sizes.isEmpty ? [nominalDesktop] : sizes
    }

    /// Screen sizes in positional order (main first) — the one
    /// place display ORDER is decided, so the space ids, the pins
    /// and the tuning all read the same sequence.
    public static func sizes(
        displays: [Display],
        mainID: DisplayID?
    ) -> [CGSize] {
        floored(
            PositionalDisplays.ordered(displays, mainID: mainID)
                .map(\.frame.size)
        )
    }

    /// Every space's layout, in positional display order — the
    /// allocation flattened, which is what the space ids number.
    static func flattened(_ sizes: [CGSize]) -> [LayoutMode] {
        StarterAllocation.modes(sizes: floored(sizes)).flatMap { $0 }
    }

    /// Total spaces for these screens.
    public static func spaceCount(sizes: [CGSize]) -> Int {
        flattened(sizes).count
    }

    /// The spaces, ids `"1"`…`"N"`, in positional display order —
    /// so `⌃⌥1` lands on the main screen, which the tour's keys
    /// step and every digit shortcut depend on.
    public static func spaces(sizes: [CGSize]) -> [SpaceID] {
        (1...max(1, spaceCount(sizes: sizes))).map { SpaceID($0) }
    }

    /// A mode for **every** space, not a sparse diff against the
    /// fallback: each space's layout was chosen for the screen it
    /// sits on, so changing the global fallback must not silently
    /// move one of them.
    public static func spaceModes(
        sizes: [CGSize]
    ) -> [SpaceID: LayoutMode] {
        var modes: [SpaceID: LayoutMode] = [:]
        for (index, mode) in flattened(sizes).enumerated() {
            modes[SpaceID(index + 1)] = mode
        }
        return modes
    }

    /// Sparse positional screen per space (0 = main). Main-display
    /// spaces are omitted (unlisted ⇒ main), so only the second
    /// display's block onward is named.
    ///
    /// Unlike the ladder's, this map cannot be re-derived from a
    /// space id by arithmetic — the blocks are no longer equal, so
    /// there is no `(n - 1) / 5`. Anything needing a space's
    /// screen reads this map.
    public static func spaceScreens(
        sizes: [CGSize]
    ) -> [SpaceID: Int] {
        var screens: [SpaceID: Int] = [:]
        var number = 1
        let blocks = StarterAllocation.modes(sizes: floored(sizes))
        for (screen, modes) in blocks.enumerated() {
            for _ in modes {
                if screen >= 1 { screens[SpaceID(number)] = screen }
                number += 1
            }
        }
        return screens
    }

    /// The setup packaged as a `StandardLayout` — the single shape
    /// shared by the `Starter` presets and the first-run seed
    /// (which composes and applies it through `applyStandard`, so
    /// the seed rides the one canonical apply path rather than
    /// re-implementing it).
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

    /// The live-display face of `standardLayout(sizes:)`.
    public static func standardLayout(
        displays: [Display],
        mainID: DisplayID?
    ) -> StandardLayout {
        standardLayout(
            sizes: sizes(displays: displays, mainID: mainID)
        )
    }
}
