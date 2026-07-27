import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

@Suite("Monocle focus cycling", .serialized)
@MainActor
struct MonocleCycleTests {
    /// Three tiled windows in a monocle space, w1 focused.
    private func makeMonocleCore() -> KiwiCore {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: 1,
                        appName: "App\(id)"
                    )
                )
            )
        }
        core.state.workspaces.focus(w1, in: SpaceID(1))
        return core
    }

    @Test("focus cycles the orientation axis, wraps when on")
    func cycleAndWrap() {
        let core = makeMonocleCore()
        // Wrap is opt-in (#257: off by default like the other
        // array-order layouts), so turn it on to exercise it.
        core.execute(
            "monocle.set_wrap_focus",
            args: [.bool(true)]
        )
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == w2)
        core.execute("focus", args: [.string("right")])
        #expect(core.activeSpace?.focused == w3)
        // Wrap: past the last window back to the first.
        core.execute("focus", args: [.string("right")])
        #expect(core.activeSpace?.focused == w1)
        // And backwards off the front to the last.
        core.execute("focus", args: [.string("left")])
        #expect(core.activeSpace?.focused == w3)
    }

    @Test("Cross-axis directions fall through to geometry")
    func crossAxisFallsThrough() {
        let core = makeMonocleCore()
        // Horizontal orientation: up/down are not intercepted,
        // and all monocle frames coincide, so there is no
        // window above — the geometric path reports that.
        let response = core.execute(
            "focus",
            args: [.string("up")]
        )
        #expect(!response.isSuccess)
        #expect(core.activeSpace?.focused == w1)
    }

    @Test("Vertical orientation cycles on up/down instead")
    func verticalAxis() {
        let core = makeMonocleCore()
        core.execute(
            "monocle.set_orientation",
            args: [.string("vertical")]
        )
        core.execute("focus", args: [.string("down")])
        #expect(core.activeSpace?.focused == w2)
        core.execute("focus", args: [.string("up")])
        #expect(core.activeSpace?.focused == w1)
        // Left/right now fall through to the geometric path.
        #expect(
            !core.execute("focus", args: [.string("right")])
                .isSuccess
        )
    }

    @Test("swap reorders the sequence but never wraps")
    func swapReorders() {
        let core = makeMonocleCore()
        #expect(
            core.execute("swap", args: [.string("right")])
                .isSuccess
        )
        #expect(
            core.activeSpace?.windows == [w2, w1, w3]
        )
        // swap never wraps (#168): from the first slot, left is a
        // no-op — a wrapping swap would teleport the window end to
        // end. focus wrapping is a separate, opt-out toggle.
        core.state.workspaces.focus(w2, in: SpaceID(1))
        #expect(
            !core.execute("swap", args: [.string("left")])
                .isSuccess
        )
        #expect(
            core.activeSpace?.windows == [w2, w1, w3]
        )
    }

    @Test("A single window is an honest dead end, not a no-op")
    func singleWindow() {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w1, pid: 1, appName: "A")
            )
        )
        core.state.workspaces.focus(w1, in: SpaceID(1))
        // #488: the lone-window press falls through the cycle so
        // the float tier can answer; with no float that way it
        // fails with the dead-end cue (matching scrolling and
        // track) instead of the old silent .ok.
        #expect(
            !core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == w1)
    }
}
