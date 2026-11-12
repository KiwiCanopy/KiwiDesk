import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `focus_space_window` (#3183 ▸ Ruling: directions of a family
/// row): one step of the Space's window list, the walk family's
/// one-shot step a split direction pre-fills with.
@Suite("Focus space window", .serialized)
@MainActor
struct FocusSpaceWindowTests {
    /// Three windows in `mode` on a pinned display, focus on `focus`.
    private func makeCore(
        focus: WindowID,
        mode: String = "grid"
    ) -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute("set_mode", args: [.string(space.raw), .string(mode)])
        core.state.workspaces.focus(focus, in: space)
        return core
    }

    private func step(_ core: KiwiCore, _ way: String) -> CommandResponse {
        core.execute("focus_space_window", args: [.string(way)])
    }

    @Test("next and prev walk the Space's order, wrapping at the ends")
    func walksTheOrder() {
        let core = makeCore(focus: WindowID(2))
        #expect(step(core, "next").isSuccess)
        #expect(core.activeSpace?.focused == WindowID(3))
        #expect(step(core, "next").isSuccess)
        #expect(core.activeSpace?.focused == WindowID(1))
        #expect(step(core, "prev").isSuccess)
        #expect(core.activeSpace?.focused == WindowID(3))
    }

    @Test("on a Scrolling row it steps as the row does, wrap and all")
    func rowStepsAlongTheRow() {
        let core = makeCore(focus: WindowID(3), mode: "scrolling")
        core.execute("set_focus_wrap", args: [.string("off")])
        // The list walk would wrap to the first window; the row's own
        // step stops at its end with wrap off.
        #expect(!step(core, "next").isSuccess)
        #expect(core.activeSpace?.focused == WindowID(3))
        #expect(step(core, "prev").isSuccess)
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("an unknown direction is refused, naming the choices")
    func unknownDirection() {
        let core = makeCore(focus: WindowID(1))
        #expect(!step(core, "left").isSuccess)
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("a lone window has nothing to step to")
    func loneWindow() {
        let core = makeTestCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: pid_t(900_001),
                    appName: "App1"
                )
            )
        )
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.state.workspaces.focus(WindowID(1), in: space)
        #expect(!step(core, "next").isSuccess)
    }

    @Test("the walk family's one-shot step is this verb")
    func walkPrefill() {
        #expect(
            GestureFamily.walk.lua(.up)
                == "KiwiDesk.focus_space_window(\"next\")"
        )
        #expect(
            GestureFamily.walk.lua(.down)
                == "KiwiDesk.focus_space_window(\"prev\")"
        )
        #expect(GestureFamily.focus.lua(.left) == "KiwiDesk.focus(\"left\")")
    }
}
