import Foundation
import Testing

@testable import KiwiDeskCore

/// The layout cycle (#453): `cycle_mode` steps the focused Space
/// through the user's list and wraps; a layout outside the list
/// sits at the seam; `set_mode_cycle` takes two layouts or more,
/// each once; the list rides `gui.json` as `mode_cycle`.
@Suite("Layout cycle (#453)")
@MainActor
struct ModeCycleTests {
    private func makeCore(mode: LayoutMode = .bsp) -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.workspaces.setMode("1", mode)
        return core
    }

    private func mode(_ core: KiwiCore) -> LayoutMode? {
        core.state.workspaces[SpaceID("1")]?.mode
    }

    @Test("Next walks the list and wraps; Previous walks back")
    func walksAndWraps() {
        let core = makeCore()
        #expect(core.modeCycle.list == [.bsp, .scrolling, .floating])
        for expected: LayoutMode in [.scrolling, .floating, .bsp] {
            #expect(core.execute("cycle_mode", args: []).isSuccess)
            #expect(mode(core) == expected)
        }
        let back = core.execute("cycle_mode", args: [.string("prev")])
        #expect(back.isSuccess)
        #expect(mode(core) == .floating)
    }

    /// Through `set_mode`'s own write, so a keyed change tells the
    /// world like a menu pick: a `layout_change` event.
    @Test("a cycle emits the layout change set_mode emits")
    func emitsLikeSetMode() {
        let core = makeCore()
        final class Count { var value = 0 }
        let changes = Count()
        _ = core.bus.addSink { event, _ in
            if event == .layoutChange { changes.value += 1 }
        }
        _ = core.execute("cycle_mode", args: [])
        #expect(changes.value == 1)
    }

    @Test("a layout outside the list goes to the seam")
    func outsideGoesToTheSeam() {
        let core = makeCore(mode: .grid)
        _ = core.execute("cycle_mode", args: [.string("next")])
        #expect(mode(core) == .bsp)
        core.state.workspaces.setMode("1", .grid)
        _ = core.execute("cycle_mode", args: [.string("prev")])
        #expect(mode(core) == .floating)
    }

    @Test("the list takes two layouts or more, each once")
    func listIsValidated() {
        let core = makeCore()
        let two = core.execute(
            "set_mode_cycle",
            args: [.array([.string("monocle"), .string("grid")])]
        )
        #expect(two.isSuccess)
        #expect(core.modeCycle.list == [.monocle, .grid])
        // The CLI's shape: one argument per layout.
        let cli = core.execute(
            "set_mode_cycle",
            args: [.string("stack"), .string("grid")]
        )
        #expect(cli.isSuccess)
        #expect(core.modeCycle.list == [.stack, .grid])
        for bad: [JSONValue] in [
            [.string("grid")],
            [.string("grid"), .string("grid")],
            [.string("grid"), .string("tabs")],
        ] {
            let response = core.execute(
                "set_mode_cycle",
                args: [.array(bad)]
            )
            #expect(!response.isSuccess)
        }
        #expect(core.modeCycle.list == [.stack, .grid])
        #expect(!core.execute("cycle_mode", args: [.string("up")]).isSuccess)
        // Listed in `move_to_track`'s order, read off `allCases`.
        #expect(ModeCycleDirection.allCases == [.prev, .next])
        // One spelling, as `move_to_track`'s: no `previous` alias.
        let alias = core.execute("cycle_mode", args: [.string("previous")])
        #expect(!alias.isSuccess)
        let number = core.execute("cycle_mode", args: [.number(1)])
        #expect(!number.isSuccess, "a non-string direction is refused")
    }

    @Test("an unreadable mode_cycle fails the file, as a strict decoder")
    func decoderIsStrict() throws {
        let json = #"{"mode_cycle": ["grid"]}"#
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(
                GuiConfig.self,
                from: Data(json.utf8)
            )
        }
        let absent = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data("{}".utf8)
        )
        #expect(absent.modeCycle == ModeCycle.defaultList)
    }
}
