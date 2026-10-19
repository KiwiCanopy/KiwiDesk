import Foundation
import Testing

@testable import KiwiDeskCore

/// `set_min_window_size(width, height?, layout?)` (#2237): no
/// layout sets every layout, no height takes the width, and a
/// layout may stand in the height's place.
@MainActor
@Suite("set_min_window_size")
struct MinWindowSizeCommandTests {
    @Test("a width alone sets every layout on both axes")
    func widthAloneSetsAll() {
        let core = makeTestCore()
        core.tiler.settings.minWindowSizes.grid = 200
        #expect(
            core.execute("set_min_window_size", args: [.number(340)]).isSuccess
        )
        #expect(core.tiler.settings.minWindowSizes == MinWindowSizes(all: 340))
    }

    @Test("width, height and a layout set that layout alone")
    func layoutSetsItsOwn() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "set_min_window_size",
                args: [.number(220), .number(160), .string("grid")]
            ).isSuccess
        )
        var expected = MinWindowSizes()
        expected.grid = MinSize(width: 220, height: 160)
        #expect(core.tiler.settings.minWindowSizes == expected)
    }

    @Test("a layout in the height's place takes the width for both")
    func layoutInHeightPlace() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "set_min_window_size",
                args: [.number(480), .string("scrolling")]
            ).isSuccess
        )
        #expect(core.tiler.settings.minWindowSizes.scrolling == 480)
        #expect(core.tiler.settings.minWindowSizes.stack == 300)
    }

    @Test("an unknown layout is refused and writes nothing")
    func unknownLayoutRefused() {
        let core = makeTestCore()
        #expect(
            !core.execute(
                "set_min_window_size",
                args: [.number(480), .string("monocle")]
            ).isSuccess
        )
        #expect(core.tiler.settings.minWindowSizes == MinWindowSizes())
    }

    @Test("an argument it cannot read is refused, not ignored")
    func strayArgumentRefused() {
        let core = makeTestCore()
        for args: [JSONValue] in [
            [.number(480), .number(300), .number(1)],
            [.number(480), .string("grid"), .string("stack")],
        ] {
            #expect(
                !core.execute("set_min_window_size", args: args)
                    .isSuccess
            )
        }
        #expect(core.tiler.settings.minWindowSizes == MinWindowSizes())
    }
}
