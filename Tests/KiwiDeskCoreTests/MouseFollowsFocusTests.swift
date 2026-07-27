import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-mouse-warp-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// Mouse follows focus (#186). The warp itself is a
/// CoreGraphics side effect; what the tests pin is the seam
/// around it: the toggle's storage and validation, the missing
/// JSON key keeping the off default, and the pure center /
/// already-inside geometry the warp decision runs on.
@Suite("Mouse follows focus (#186)", .serialized)
@MainActor
struct MouseFollowsFocusTests {
    @Test("mouse.set_follows_focus toggles and validates")
    func toggle() {
        let core = makeCore()
        #expect(!core.tiler.settings.mouse.followsFocus)
        #expect(
            core.execute(
                "mouse.set_follows_focus",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.tiler.settings.mouse.followsFocus)
        #expect(
            !core.execute(
                "mouse.set_follows_focus",
                args: [.string("yes")]
            ).isSuccess
        )
        #expect(core.tiler.settings.mouse.followsFocus)
        #expect(
            !core.execute(
                "mouse.set_something_else",
                args: [.bool(true)]
            ).isSuccess
        )
    }

    @Test("The warp guard chain gates on toggle, space, piles")
    func eligibility() {
        // NSEvent.pressedMouseButtons is assumed 0 while the
        // suite runs (nobody is clicking during `swift test`).
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "A")
            )
        )
        let id = WindowID(1)
        // Toggle off (the default): never eligible.
        #expect(!core.mouseWarpEligible(id))
        core.tiler.settings.mouse.followsFocus = true
        #expect(core.mouseWarpEligible(id))
        // A z-order restore in flight holds the warp: its pile
        // raises steal focus without user intent (#186).
        core.zOrderRestoresInFlight = 1
        #expect(!core.mouseWarpEligible(id))
        core.zOrderRestoresInFlight = 0
        #expect(core.mouseWarpEligible(id))
        // A window on no (or an inactive) space never warps.
        #expect(!core.mouseWarpEligible(WindowID(99)))
    }

    @Test("A partial mouse object keeps the off default")
    func partialDecode() throws {
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(#"{"mouse":{}}"#.utf8)
        )
        #expect(!decoded.mouse.followsFocus)
    }

    @Test("Warp targets the frame center")
    func center() {
        let frame = CGRect(x: 100, y: 200, width: 400, height: 300)
        let target = MouseWarp.target(
            frame: frame,
            cursor: CGPoint(x: 0, y: 0)
        )
        #expect(target == CGPoint(x: 300, y: 350))
    }

    @Test("A cursor already inside the frame skips the warp")
    func alreadyInside() {
        let frame = CGRect(x: 100, y: 200, width: 400, height: 300)
        let inside = MouseWarp.target(
            frame: frame,
            cursor: CGPoint(x: 101, y: 201)
        )
        #expect(inside == nil)
        // On the max edge — excluded by `contains`, but a
        // pointer fresh from an edge resize sits exactly
        // there; the 1 pt slack treats it as inside.
        let onEdge = MouseWarp.target(
            frame: frame,
            cursor: CGPoint(x: 500, y: 500)
        )
        #expect(onEdge == nil)
    }

    @Test("An unknown cursor position still warps")
    func unknownCursor() {
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let target = MouseWarp.target(frame: frame, cursor: nil)
        #expect(target == CGPoint(x: 50, y: 50))
    }

    @Test("An empty frame never warps")
    func emptyFrame() {
        #expect(
            MouseWarp.target(
                frame: .zero,
                cursor: CGPoint(x: 5, y: 5)
            ) == nil
        )
    }
}
