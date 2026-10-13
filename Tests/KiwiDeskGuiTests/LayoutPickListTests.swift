import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Layouts scope's tiles (#2229): the filter matches by prefix
/// then substring and dims the rest in place, the arrows walk the
/// matches without wrapping, and the ⌘ digits name a position the
/// filter never moves.
@Suite("Layout picker tiles")
struct LayoutPickListTests {
    private static let names: [LayoutMode: String] = [
        .bsp: "BSP", .stack: "Stack", .scrolling: "Scrolling",
        .grid: "Grid", .monocle: "Monocle", .track: "Track",
        .floating: "Floating",
    ]

    private func list(live: LayoutMode = .scrolling) -> LayoutPickList {
        LayoutPickList(
            state: LayoutPickerState(
                space: "3",
                live: live,
                drifted: false,
                profile: nil,
                keepArmed: false
            ),
            names: Self.names
        )
    }

    @Test("it opens on the live layout")
    func opensOnLive() {
        #expect(list(live: .grid).selected == .grid)
    }

    @Test("a prefix match outranks a substring match")
    func prefixFirst() {
        var list = list()
        list.setQuery("o")
        // Only names containing an "o" match; none starts with one.
        #expect(list.selected == .scrolling)
        list.setQuery("mon")
        #expect(list.selected == .monocle)
        let monocle = LayoutMode.allCases.firstIndex(of: .monocle)!
        #expect(list.matches == [monocle])
        // "s" starts Stack and Scrolling and is only inside BSP,
        // which is drawn first: the prefix still wins.
        list.setQuery("s")
        #expect(list.selected == .stack)
    }

    @Test("non-matches dim and stay in place")
    func dimsInPlace() {
        var list = list()
        list.setQuery("st")
        let stack = LayoutMode.allCases.firstIndex(of: .stack)!
        let grid = LayoutMode.allCases.firstIndex(of: .grid)!
        #expect(!list.isDimmed(stack))
        #expect(list.isDimmed(grid))
        #expect(list.modes == LayoutMode.allCases)
    }

    @Test("no match selects nothing; clearing returns to the live")
    func noMatch() {
        // Not the first tile, so "back to live" and "back to the
        // first tile" answer apart.
        var list = list(live: .grid)
        list.setQuery("xyz")
        #expect(list.selected == nil)
        list.setQuery("")
        #expect(list.selected == .grid)
    }

    @Test("the arrows walk the matches and never wrap")
    func stepping() {
        var list = list(live: .bsp)
        list.step(-1)
        #expect(list.selected == .bsp)
        list.step(1)
        #expect(list.selected == LayoutMode.allCases[1])
        list.setQuery("ck")
        // Stack and Track match; the walk stays among them.
        #expect(list.selected == .stack)
        list.step(1)
        #expect(list.selected == .track)
        list.step(1)
        #expect(list.selected == .track)
    }

    @Test("a ⌘ digit names its position whatever the filter")
    func quick() {
        var list = list()
        list.setQuery("mon")
        #expect(list.quick(0) == LayoutMode.allCases[0])
        #expect(list.quick(7) == nil)
    }

    /// A native-script name still answers the config's spelling.
    @Test("the config's spelling matches beside the drawn name")
    func rawSpellingMatches() {
        var names = Self.names
        names[.monocle] = "モノクル"
        var list = LayoutPickList(
            state: LayoutPickerState(
                space: "3",
                live: .bsp,
                drifted: false,
                profile: nil,
                keepArmed: false
            ),
            names: names
        )
        list.setQuery("mon")
        #expect(list.selected == .monocle)
    }
}
