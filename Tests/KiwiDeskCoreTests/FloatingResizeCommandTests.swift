import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `resize` on a floating focused window resizes the window
/// itself — in every layout mode, including the floating
/// layout, where tiled resize replies "not supported".
@Suite("Floating keyboard resize", .serialized)
@MainActor
struct FloatingResizeCommandTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return KiwiCore(configDirectory: dir)
    }

    /// Two windows in the given mode; w2 focused, floating,
    /// with a known frame. The animation engine is disabled so
    /// `animate` applies the target synchronously through the
    /// observable `apply` hook (the MoveToSpaceTests pattern).
    private func floatingSetup(
        _ core: KiwiCore,
        mode: String,
        applied:
            @escaping @MainActor (
                WindowID, CGRect
            ) -> Void
    ) {
        core.execute(
            "set_mode",
            args: [.string("1"), .string(mode)]
        )
        for index in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
        core.state.apply(
            .windowResized(
                WindowID(2),
                CGRect(x: 100, y: 100, width: 600, height: 500)
            )
        )
        core.state.apply(.windowFocused(WindowID(2)))
        core.state.setFloating(WindowID(2), true)
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
    }

    @Test("x widens the floating window; layout untouched")
    func widensTheFloat() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        floatingSetup(core, mode: "bsp") { frames[$0] = $1 }
        let ratioBefore = core.tiler.settings.bsp.splitRatioH
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(200)]
        )
        #expect(response.isSuccess)
        #expect(frames[WindowID(2)]?.width == 800)
        #expect(frames[WindowID(2)]?.height == 500)
        #expect(frames[WindowID(2)]?.origin.x == 100)
        #expect(
            core.tiler.settings.bsp.splitRatioH == ratioBefore
        )
    }

    @Test("y shrink stops at min_window_size")
    func shrinkFloorsAtMinSize() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        floatingSetup(core, mode: "stack") { frames[$0] = $1 }
        core.execute(
            "set_min_window_size",
            args: [.number(300)]
        )
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(-10_000)]
        )
        #expect(response.isSuccess)
        #expect(frames[WindowID(2)]?.height == 300)
        #expect(frames[WindowID(2)]?.width == 600)
    }

    @Test("works in the floating layout too")
    func worksInFloatingLayout() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        floatingSetup(core, mode: "floating") {
            frames[$0] = $1
        }
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(150)]
        )
        #expect(response.isSuccess)
        #expect(frames[WindowID(2)]?.height == 650)
    }

    @Test("a tiled focus in the floating layout still fails")
    func tiledFocusInFloatingLayoutStillFails() {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("floating")]
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "A"
                )
            )
        )
        // Created (and auto-focused) but never flagged
        // floating: the tiled dispatch keeps rejecting the
        // floating layout.
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(100)]
        )
        #expect(!response.isSuccess)
    }
}
