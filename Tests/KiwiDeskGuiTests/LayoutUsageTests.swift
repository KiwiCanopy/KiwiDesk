import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Which spaces run which layout (#678 turn 10) — the one answer
/// the strip's per-tile counts, the spaces-using card and the
/// page's landing layout all read.
///
/// It is guarded because the landing's reading CHANGED when the
/// three were merged: it used to count `spaceModes.values` alone,
/// which credited nothing to BSP for a space the user had never
/// touched, so a profile of untouched spaces plus one Grid space
/// landed the reader on Grid under a tile saying BSP had the
/// spaces. Reverting to that reading has to red something, and
/// the three inputs below are what it reds.
@Suite("Layout usage")
struct LayoutUsageTests {
    private func config(
        _ spaces: [String],
        modes: [String: LayoutMode] = [:]
    ) -> GuiConfig {
        var config = GuiConfig()
        config.spaces = spaces.map { SpaceID($0) }
        for (space, mode) in modes {
            config.spaceModes[SpaceID(space)] = mode
        }
        return config
    }

    /// A space with no recorded mode runs the default, which is
    /// the reading every other surface in the app uses — so it
    /// counts toward BSP rather than toward nothing.
    @Test("an unrecorded space counts as the default")
    func unrecordedSpacesAreBsp() {
        let config = config(["1", "2", "3", "4"], modes: ["4": .grid])
        #expect(
            LayoutUsage.spaces(on: .bsp, in: config).count == 3
        )
        #expect(
            LayoutUsage.spaces(on: .grid, in: config)
                == [SpaceID("4")]
        )
        // The landing agrees with the counts above — the whole
        // reason the three readings became one.
        #expect(LayoutUsage.mostUsed(in: config) == .bsp)
    }

    /// The list is the user's own space ORDER, not a set: the
    /// chips read in the order the spaces do everywhere else.
    @Test("the list keeps the user's space order")
    func keepsSpaceOrder() {
        let config = config(
            ["z", "a", "m"],
            modes: ["z": .track, "a": .track, "m": .track]
        )
        #expect(
            LayoutUsage.spaces(on: .track, in: config)
                == [SpaceID("z"), SpaceID("a"), SpaceID("m")]
        )
    }

    /// Floating has nothing to tune and so no tile — it can never
    /// win the landing, however many spaces run it. The fallback
    /// is BSP, and it is reached whenever no TUNED layout has a
    /// space, which an all-Floating profile is the live case of.
    @Test("Floating never wins the landing")
    func floatingNeverLands() {
        let config = config(
            ["1", "2"],
            modes: ["1": .floating, "2": .floating]
        )
        #expect(LayoutUsage.mostUsed(in: config) == .bsp)
        #expect(
            LayoutUsage.spaces(on: .floating, in: config).count
                == 2
        )
    }

    /// An empty profile has no maximum to take, so the fallback
    /// carries it.
    @Test("an empty profile lands on the fallback")
    func emptyProfile() {
        #expect(LayoutUsage.mostUsed(in: config([])) == .bsp)
    }

    /// A tie resolves by `LayoutMode.placementTabs` order, which
    /// is the curated strip order — so the landing is the
    /// leftmost tied tile rather than whatever a dictionary
    /// happened to yield, which is what the old reading gave.
    @Test("a tie lands on the leftmost tied layout")
    func tieBreaksByStripOrder() {
        let config = config(
            ["1", "2"],
            modes: ["1": .track, "2": .stack]
        )
        let tabs = LayoutMode.placementTabs
        let expected =
            tabs.firstIndex(of: .stack)! < tabs.firstIndex(of: .track)!
            ? LayoutMode.stack : .track
        #expect(LayoutUsage.mostUsed(in: config) == expected)
    }
}
