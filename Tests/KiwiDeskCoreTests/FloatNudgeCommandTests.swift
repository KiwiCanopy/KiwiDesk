import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `move_floating` (#2972), one press at a time: the step, the stop,
/// the refusals. The hold is `FloatNudgeGlideTests`'. A write is read
/// off the instant stamp the applier leaves, the store it lands in.
@Suite("Move floating", .serialized)
@MainActor
struct FloatNudgeCommandTests {
    private let one = WindowID(1)
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let start = CGRect(x: 100, y: 100, width: 400, height: 300)

    private func makeCore(
        frame: CGRect? = nil,
        floating: Bool = true
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-float-nudge-\(UUID().uuidString)"
                )
        )
        let screen = self.screen
        core.tiler.visibleBounds = { _ in screen }
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: one,
                    pid: 900_001,
                    appName: "App",
                    frame: frame ?? start,
                    isFloating: floating
                )
            )
        )
        core.state.apply(.windowFocused(one))
        return core
    }

    private func move(
        _ core: KiwiCore,
        _ axis: String,
        _ delta: Double
    ) -> CommandResponse {
        core.execute(
            "move_floating",
            args: [.string(axis), .number(delta)]
        )
    }

    private func commanded(_ core: KiwiCore) -> CGRect? {
        core.tiler.recentInstantTarget(one)
    }

    @Test("x moves right, y moves down, the size stays")
    func moves() {
        let core = makeCore()
        #expect(move(core, "x", 30).isSuccess)
        expectEqual(commanded(core), start.offsetBy(dx: 30, dy: 0))
        let again = makeCore()
        #expect(move(again, "y", -40).isSuccess)
        expectEqual(commanded(again), start.offsetBy(dx: 0, dy: -40))
    }

    /// Gated: with no screen `applyFrame` is instant whatever it is
    /// asked, so this would hold nothing.
    @Test(
        "a press writes instantly, the toggles on",
        .enabled(if: NSScreen.main != nil)
    )
    func instant() {
        let core = makeCore()
        core.tiler.settings.animations.onStateChange = true
        core.tiler.settings.animations.onWindowResize = true
        #expect(move(core, "x", 30).isSuccess)
        expectEqual(commanded(core)?.minX, start.minX + 30)
        #expect(!core.tiler.animation.isAnimating(window: one))
    }

    @Test("a bad axis or a missing delta answers the contract")
    func parses() {
        let core = makeCore()
        #expect(!move(core, "z", 30).isSuccess)
        #expect(!core.execute("move_floating").isSuccess)
        #expect(!move(core, "x", .infinity).isSuccess)
        #expect(commanded(core) == nil)
    }

    @Test("a stop lands on the wall and cues the way it was going")
    func stops() {
        let cases: [(String, Double, Direction, CGRect)] = [
            ("x", 5000, .right, start.offsetBy(dx: 1100, dy: 0)),
            ("x", -5000, .left, start.offsetBy(dx: -100, dy: 0)),
            ("y", 5000, .down, start.offsetBy(dx: 0, dy: 600)),
            ("y", -5000, .up, start.offsetBy(dx: 0, dy: -100)),
        ]
        for (axis, delta, direction, landing) in cases {
            var cues: [ResizeRefusal] = []
            let core = makeCore()
            core.borders.onResizeRefusal = { cues.append($0) }
            #expect(move(core, axis, delta).isSuccess)
            expectEqual(commanded(core), landing)
            expectEqual(cues, [.moveAtBoundary(one, direction: direction)])
        }
    }

    @Test("a move that fits exactly is no stop")
    func exactFit() {
        var cues: [ResizeRefusal] = []
        let core = makeCore()
        core.borders.onResizeRefusal = { cues.append($0) }
        #expect(move(core, "x", 1100).isSuccess)
        expectEqual(commanded(core)?.maxX, screen.maxX)
        #expect(cues.isEmpty)
    }

    @Test("parked past an edge: out stays put, back travels freely")
    func parked() {
        let past = CGRect(x: 1500, y: 100, width: 400, height: 300)
        var cues: [ResizeRefusal] = []
        let core = makeCore(frame: past)
        core.borders.onResizeRefusal = { cues.append($0) }
        #expect(move(core, "x", 10).isSuccess)
        #expect(commanded(core) == nil)
        expectEqual(cues, [.moveAtBoundary(one, direction: .right)])
        let back = makeCore(frame: past)
        #expect(move(back, "x", -10).isSuccess)
        expectEqual(commanded(back)?.minX, past.minX - 10)
        // Past the left edge, the same two ways round.
        let left = past.offsetBy(dx: -1600, dy: 0)
        let out = makeCore(frame: left)
        #expect(move(out, "x", -10).isSuccess)
        #expect(commanded(out) == nil)
    }

    @Test("a window larger than the region stops at its left edge")
    func oversized() {
        let big = CGRect(x: 0, y: 0, width: 2000, height: 300)
        let core = makeCore(frame: big)
        #expect(move(core, "x", 10).isSuccess)
        #expect(commanded(core) == nil)
        let left = CGRect(x: -50, y: 0, width: 2000, height: 300)
        let inward = makeCore(frame: left)
        #expect(move(inward, "x", 10).isSuccess)
        expectEqual(commanded(inward)?.minX, -40)
    }

    /// A step far under a point at a wall still counts as stopped, or
    /// a nudge-sized hold never ends there.
    @Test("a tiny step at the wall is a stop")
    func tinyStop() {
        var cues: [ResizeRefusal] = []
        let atWall = start.offsetBy(dx: 1100, dy: 0)
        let core = makeCore(frame: atWall)
        core.borders.onResizeRefusal = { cues.append($0) }
        #expect(move(core, "x", 0.1).isSuccess)
        #expect(commanded(core) == nil)
        expectEqual(cues, [.moveAtBoundary(one, direction: .right)])
    }

    @Test("a bar's push never sends a step back against the ask")
    func holdsTheAsk() {
        let base = CGRect(x: 50, y: 50, width: 100, height: 100)
        for (horizontal, delta, pushed): (Bool, Double, CGRect) in [
            (false, -1, base.offsetBy(dx: 0, dy: 2)),
            (false, 1, base.offsetBy(dx: 0, dy: -2)),
            (true, -1, base.offsetBy(dx: 2, dy: 0)),
            (true, 1, base.offsetBy(dx: -2, dy: 0)),
        ] {
            #expect(
                FloatMove.holdingTheAsk(
                    pushed,
                    from: base,
                    horizontal: horizontal,
                    delta: delta
                ) == base
            )
        }
        // A push the way it was going is the ask's own.
        let ahead = base.offsetBy(dx: 0, dy: 2)
        #expect(
            FloatMove.holdingTheAsk(
                ahead,
                from: base,
                horizontal: false,
                delta: 1
            ) == ahead
        )
    }

    @Test("a tiled focus refuses with the pill and is not floated")
    func tiledRefuses() {
        var cues: [ResizeRefusal] = []
        let core = makeCore(floating: false)
        core.borders.onResizeRefusal = { cues.append($0) }
        #expect(!move(core, "x", 10).isSuccess)
        expectEqual(cues, [.moveNeedsFloat(one)])
        #expect(commanded(core) == nil)
        expectEqual(core.state.windows[one]?.isFloating, false)
    }

    @Test("full screen refuses first, tiled or floating")
    func fullscreenFirst() {
        for floating in [true, false] {
            var cues: [ResizeRefusal] = []
            let core = makeCore(floating: floating)
            core.borders.onResizeRefusal = { cues.append($0) }
            core.state.apply(.windowFullscreenChanged(one, isFullscreen: true))
            #expect(!move(core, "x", 10).isSuccess)
            expectEqual(cues, [.fullscreenCannotMove(one)])
            #expect(commanded(core) == nil)
        }
    }

    @Test("a floating-mode member is a float")
    func floatingMode() {
        let core = makeCore(floating: false)
        core.execute(
            "set_mode",
            args: [.string("1"), .string("floating")]
        )
        #expect(move(core, "x", 30).isSuccess)
        expectEqual(commanded(core)?.minX, start.minX + 30)
    }

    @Test("a drag or an aspect probe stands the verb down")
    func standsDown() {
        let dragged = makeCore()
        dragged.tiler.dragExemptWindow = one
        #expect(move(dragged, "x", 30).isSuccess)
        #expect(commanded(dragged) == nil)
        let probed = makeCore()
        probed.state.floatAspectFlight = .probing(one)
        probed.deferred.schedule(.floatAspect, after: .seconds(60)) {}
        defer { probed.deferred.cancel(.floatAspect) }
        #expect(move(probed, "x", 30).isSuccess)
        #expect(commanded(probed) == nil)
    }

    /// The question #2972 left to the implementation: a move ends no
    /// maximize, since a float holds none and the tile keeps its own.
    @Test("a maximized tile beneath keeps its maximize")
    func maximizeStands() {
        let core = makeCore()
        let tile = WindowID(2)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: tile,
                    pid: 900_002,
                    appName: "Tile",
                    frame: screen
                )
            )
        )
        let space = SpaceID("1")
        core.state.workspaces.withSpace(space) {
            $0.maximized = tile
            $0.focused = one
        }
        #expect(move(core, "x", 30).isSuccess)
        expectEqual(commanded(core)?.minX, start.minX + 30)
        expectEqual(core.state.workspaces[space]?.maximized, tile)
    }
}
