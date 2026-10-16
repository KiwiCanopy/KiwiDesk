import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The View side's lines (#2229, #2309): one filter over all three
/// lines that dims the rest in place, ← → along a line and ↑ ↓
/// between lines keeping the position, and the ⌘ numbers counted
/// on the selected line among its matches.
@Suite("View picker lines")
struct ViewPickListTests {
    private typealias Item = ViewPickList.Item

    private func list(
        live: LayoutMode = .scrolling,
        profiles: [String] = ["Laptop", "Studio", "Presenting"],
        monocle: String = "Monocle"
    ) -> ViewPickList {
        let layouts = LayoutMode.allCases.map { mode in
            Item(
                pick: .layout(mode),
                name: mode == .monocle ? monocle : mode.rawValue.capitalized,
                spellings: [mode.rawValue],
                isCurrent: mode == live
            )
        }
        let profileItems = profiles.enumerated().map {
            Item(pick: .profile($1), name: $1, isCurrent: $0 == 0)
        }
        let vision = [
            Item(pick: .vision(false), name: "Off", isCurrent: true),
            Item(pick: .vision(true), name: "Focused window"),
        ]
        return ViewPickList(
            layout: LayoutPickerState(
                space: "3",
                live: live,
                drifted: false,
                profile: nil,
                keepArmed: false
            ),
            items: [
                .layout: layouts, .profile: profileItems, .vision: vision,
            ]
        )
    }

    @Test("it opens on the Layout line's live layout")
    func opensOnLive() {
        #expect(list(live: .grid).selected?.pick == .layout(.grid))
        #expect(list().selection?.line == .layout)
    }

    @Test("an empty line is not drawn")
    func emptyLineIsAbsent() {
        #expect(list(profiles: []).lines == [.layout, .vision])
    }

    @Test("a prefix match outranks a substring match")
    func prefixFirst() {
        var list = list()
        list.setQuery("mon")
        #expect(list.selected?.pick == .layout(.monocle))
        // "s" starts Stack and Scrolling and is only inside BSP,
        // which is drawn first: the prefix still wins.
        list.setQuery("s")
        #expect(list.selected?.pick == .layout(.stack))
    }

    @Test("a query no layout matches lands on the next line")
    func searchCrossesLines() {
        var list = list()
        list.setQuery("stu")
        #expect(list.selected?.pick == .profile("Studio"))
        list.setQuery("focus")
        #expect(list.selected?.pick == .vision(true))
    }

    @Test("non-matches dim and stay in place")
    func dimsInPlace() {
        var list = list()
        list.setQuery("st")
        let stack = LayoutMode.allCases.firstIndex(of: .stack)!
        let grid = LayoutMode.allCases.firstIndex(of: .grid)!
        #expect(!list.isDimmed(.layout, stack))
        #expect(list.isDimmed(.layout, grid))
        #expect(list.items(.layout).count == LayoutMode.allCases.count)
    }

    @Test("no match selects nothing; clearing returns to the current")
    func noMatch() {
        // Not the first tile, so "back to the current" and "back
        // to the first tile" answer apart.
        var list = list(live: .grid)
        list.setQuery("xyz")
        #expect(list.selected == nil)
        list.setQuery("")
        #expect(list.selected?.pick == .layout(.grid))
    }

    @Test("← → walk a line's matches and never wrap")
    func stepping() {
        var list = list(live: .bsp)
        list.step(-1)
        #expect(list.selected?.pick == .layout(.bsp))
        list.step(1)
        #expect(list.selected?.pick == .layout(LayoutMode.allCases[1]))
        list.setQuery("ck")
        // Stack and Track match; the walk stays among them.
        #expect(list.selected?.pick == .layout(.stack))
        list.step(1)
        #expect(list.selected?.pick == .layout(.track))
        list.step(1)
        #expect(list.selected?.pick == .layout(.track))
    }

    /// Ruling 11: ↑ ↓ keep the position along the line, clamped to
    /// a shorter one, and never leave the first or last line.
    @Test("↑ ↓ keep the position, clamped")
    func movingLines() {
        var list = list(live: .bsp)
        list.step(1)
        list.moveLine(1)
        #expect(list.selected?.pick == .profile("Studio"))
        list.step(1)
        list.moveLine(1)
        #expect(list.selected?.pick == .vision(true))
        list.moveLine(1)
        #expect(list.selected?.pick == .vision(true))
        list.moveLine(-1)
        #expect(list.selected?.pick == .profile("Studio"))
        list.moveLine(-1)
        list.moveLine(-1)
        #expect(list.selected?.pick == .layout(LayoutMode.allCases[1]))
    }

    @Test("↑ ↓ pass over a line the query empties")
    func movingSkipsEmptyLines() {
        var list = list()
        list.setQuery("f")
        #expect(list.selected?.pick == .layout(.floating))
        // "f" is in no profile name here, so ↓ lands on KiwiVision.
        list.moveLine(1)
        #expect(list.selection?.line == .vision)
    }

    /// Ruling 4: the number counts on the selected line, among its
    /// matches while a query is typed, and stops at nine.
    @Test("⌘ numbers count the selected line's matches")
    func quickNumbers() {
        var list = list()
        #expect(list.quick(0)?.pick == .layout(LayoutMode.allCases[0]))
        list.setQuery("ck")
        #expect(list.quick(0)?.pick == .layout(.stack))
        #expect(list.quick(1)?.pick == .layout(.track))
        #expect(list.quick(2) == nil)
        let track = LayoutMode.allCases.firstIndex(of: .track)!
        #expect(list.number(.layout, track) == 2)
        #expect(list.number(.layout, 0) == nil)
        list.setQuery("")
        list.moveLine(1)
        #expect(list.quick(1)?.pick == .profile("Studio"))
    }

    @Test("nothing past the ninth item takes a number")
    func ninthIsTheLast() {
        let many = (1...12).map { "P\($0)" }
        var list = list(profiles: many)
        list.moveLine(1)
        #expect(list.number(.profile, 8) == 9)
        #expect(list.number(.profile, 9) == nil)
        #expect(list.quick(9) == nil)
    }

    /// A native-script name still answers the config's spelling.
    @Test("the config's spelling matches beside the drawn name")
    func rawSpellingMatches() {
        var list = list(monocle: "モノクル")
        list.setQuery("mon")
        #expect(list.selected?.pick == .layout(.monocle))
    }
}
