import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// Boots `count` windows into the active space, switches it to
/// scrolling, and focuses `focus`. Returns the space id.
@MainActor
@discardableResult
private func makeScrollingSpace(
    _ core: KiwiCore,
    windows count: Int,
    focus: WindowID
) -> SpaceID {
    for id in 1...count {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: pid_t(id),
                    appName: "App\(id)"
                )
            )
        )
    }
    let space = core.state.workspaces.space(of: WindowID(1))!
    core.execute(
        "set_mode",
        args: [.string(space.raw), .string("scrolling")]
    )
    core.state.workspaces.focus(focus, in: space)
    return space
}

/// Array-order navigation along the scroll axis (#147): pinned
/// slots share identical frames, so scrolling `focus`/`swap`
/// must step the flat array on the orientation axis instead of
/// searching geometry — regardless of the viewport position.
@Suite("Scrolling navigation", .serialized)
@MainActor
struct ScrollingNavigationTests {
    @Test("Horizontal focus steps the array, any scroll offset")
    func horizontalFocusStepsArray() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 5,
            focus: WindowID(3)
        )
        // Scrolled far both ways: with 5 windows the far slots
        // pin at identical edge slivers (#142); array stepping
        // must not care.
        for offset in [CGFloat(-4000), 0, 4000] {
            core.state.workspaces.withSpace(space) {
                $0.scrollRest = ScrollRest(offset: offset)
            }
            core.state.workspaces.focus(WindowID(3), in: space)
            #expect(
                core.execute("focus", args: [.string("left")])
                    .isSuccess
            )
            #expect(core.activeSpace?.focused == WindowID(2))
            core.state.workspaces.focus(WindowID(3), in: space)
            #expect(
                core.execute("focus", args: [.string("right")])
                    .isSuccess
            )
            #expect(core.activeSpace?.focused == WindowID(4))
        }
    }

    @Test("Horizontal swap reorders with the array neighbor")
    func horizontalSwapUsesArrayNeighbor() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 5,
            focus: WindowID(3)
        )
        core.state.workspaces.withSpace(space) {
            $0.scrollRest = ScrollRest(offset: 4000)
        }
        #expect(
            core.execute("swap", args: [.string("left")])
                .isSuccess
        )
        #expect(
            core.state.workspaces[space]?.windows
                == [1, 3, 2, 4, 5].map { WindowID($0) }
        )
        #expect(core.activeSpace?.focused == WindowID(3))
        #expect(
            core.execute("swap", args: [.string("right")])
                .isSuccess
        )
        #expect(
            core.state.workspaces[space]?.windows
                == [1, 2, 3, 4, 5].map { WindowID($0) }
        )
    }

    @Test("Vertical orientation steps on up/down")
    func verticalFocusStepsArray() {
        let core = makeCore()
        core.execute(
            "scroll.set_orientation",
            args: [.string("vertical")]
        )
        let space = makeScrollingSpace(
            core,
            windows: 5,
            focus: WindowID(3)
        )
        #expect(
            core.execute("focus", args: [.string("up")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(2))
        #expect(
            core.execute("focus", args: [.string("down")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(3))
        #expect(
            core.execute("swap", args: [.string("down")])
                .isSuccess
        )
        #expect(
            core.state.workspaces[space]?.windows
                == [1, 2, 4, 3, 5].map { WindowID($0) }
        )
    }

    @Test("Per-space orientation override picks the step axis")
    func overrideOrientationGatesAxis() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 3,
            focus: WindowID(2)
        )
        core.execute(
            "scroll.set_orientation_override",
            args: [.string(space.raw), .string("vertical")]
        )
        #expect(
            core.execute("focus", args: [.string("up")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("Cross-axis directions fall through geometrically")
    func crossAxisFallsThrough() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 3, focus: WindowID(2))
        // Horizontal row: nothing lies above/below the slots,
        // so the geometric search reports no neighbor. Had the
        // array step claimed the direction, it would move focus.
        let up = core.execute("focus", args: [.string("up")])
        #expect(!up.isSuccess)
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("Row ends do not wrap")
    func rowEndsDoNotWrap() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 3,
            focus: WindowID(1)
        )
        let left = core.execute("focus", args: [.string("left")])
        #expect(!left.isSuccess)
        #expect(core.activeSpace?.focused == WindowID(1))
        core.state.workspaces.focus(WindowID(3), in: space)
        let right = core.execute(
            "swap",
            args: [.string("right")]
        )
        #expect(!right.isSuccess)
        #expect(
            core.state.workspaces[space]?.windows
                == [1, 2, 3].map { WindowID($0) }
        )
    }

    @Test("Floating focus falls through to geometry")
    func floatingFocusFallsThrough() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 3, focus: WindowID(2))
        core.execute("make_floating")
        // The floating window has no slot and frame .zero; the
        // geometric search finds no tiled window left of it.
        // The array step must not claim it (it is not tiled).
        let left = core.execute("focus", args: [.string("left")])
        #expect(!left.isSuccess)
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("Focus steps tiled adjacency across a floater")
    func focusSkipsInterleavedFloater() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 3,
            focus: WindowID(2)
        )
        core.execute("make_floating")
        core.state.workspaces.focus(WindowID(3), in: space)
        // [1, 2(floating), 3]: the step walks tiled neighbors,
        // so left of 3 is 1, not the floater between them.
        #expect(
            core.execute("focus", args: [.string("left")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("Swap trades raw positions across a floater")
    func swapCrossesInterleavedFloater() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 3,
            focus: WindowID(2)
        )
        core.execute("make_floating")
        core.state.workspaces.focus(WindowID(3), in: space)
        // Tiled neighbor left of 3 is 1; the swap exchanges
        // their raw array slots, leaving the floater in place.
        #expect(
            core.execute("swap", args: [.string("left")])
                .isSuccess
        )
        #expect(
            core.state.workspaces[space]?.windows
                == [3, 2, 1].map { WindowID($0) }
        )
        #expect(core.activeSpace?.focused == WindowID(3))
    }

    @Test("Monocle wraps when wrap_focus is on")
    func monocleCycleUntouched() {
        let core = makeCore()
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(
            of: WindowID(1)
        )!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("monocle")]
        )
        // Wrap is opt-in (#257); enable it to cycle past the end.
        core.execute(
            "monocle.set_wrap_focus",
            args: [.bool(true)]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        #expect(
            core.execute("focus", args: [.string("left")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(3))
    }
}
