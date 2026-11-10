import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `center_floating` (#3007): the ruling's refusals, its size and
/// its independence from `float_placement`. The Space it reads is
/// `FloatCentreRenderSpaceTests`'.
@Suite("Center floating", .serialized)
@MainActor
struct FloatCentreCommandTests {
    private let one = WindowID(1)
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let start = CGRect(x: 20, y: 30, width: 400, height: 300)

    /// Space 1 with w1 focused at `start`, floating when asked. The
    /// engine is off, so a write lands on the `apply` hook.
    private func makeCore(
        floating: Bool = true,
        applied: @escaping @MainActor (WindowID, CGRect) -> Void = {
            _,
            _ in
        }
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-float-centre-\(UUID().uuidString)"
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
                    frame: start,
                    isFloating: floating
                )
            )
        )
        core.state.apply(.windowFocused(one))
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
        return core
    }

    @Test("centres in the float region at the window's own size")
    func centres() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        #expect(core.execute("center_floating").isSuccess)
        let frame = try #require(frames[one])
        #expect(frame.size == start.size)
        #expect(frame.midX == screen.midX)
        #expect(frame.midY == screen.midY)
    }

    /// The size base outranks the echo: a size just commanded and
    /// not yet reported is what gets centred.
    @Test("centres the commanded size, not the echo's")
    func commandedSize() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        let big = CGSize(width: 900, height: 700)
        core.tiler.applyFrame(
            one,
            from: start,
            to: CGRect(origin: start.origin, size: big),
            animated: false
        )
        #expect(core.execute("center_floating").isSuccess)
        #expect(frames[one]?.size == big)
    }

    @Test("an oversized window pins top and left and is not shrunk")
    func oversized() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        let huge = CGRect(x: 40, y: 40, width: 2000, height: 1400)
        core.state.apply(.windowResized(one, huge))
        #expect(core.execute("center_floating").isSuccess)
        #expect(frames[one] == CGRect(origin: .zero, size: huge.size))
    }

    @Test("one oversized axis pins alone; the other still centres")
    func oversizedOneAxis() throws {
        let tall = FloatPlacement.centered(
            CGSize(width: 400, height: 1400),
            in: screen
        )
        #expect(tall.minY == screen.minY)
        #expect(tall.midX == screen.midX)
        let wide = FloatPlacement.centered(
            CGSize(width: 2000, height: 300),
            in: screen
        )
        #expect(wide.minX == screen.minX)
        #expect(wide.midY == screen.midY)
    }

    /// Named on neither toggle but `on_state_change`: off, the write
    /// is instant and misses the engine's hook.
    @Test("on_state_change decides the route")
    func followsTheToggle() {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.tiler.settings.animations.onStateChange = false
        #expect(core.execute("center_floating").isSuccess)
        #expect(frames[one] == nil)
        #expect(core.tiler.recentInstantTarget(one)?.midX == screen.midX)
    }

    @Test("a tiled focus refuses with a pill and is not floated")
    func tiledRefuses() {
        var cues: [ResizeRefusal] = []
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore(floating: false) { frames[$0] = $1 }
        core.borders.onResizeRefusal = { cues.append($0) }
        frames.removeAll()
        #expect(!core.execute("center_floating").isSuccess)
        #expect(cues == [.moveNeedsFloat(one)])
        #expect(frames[one] == nil)
        #expect(core.state.windows[one]?.isFloating == false)
    }

    /// Full screen is asked first, or a tiled full-screen window
    /// reads as "only a floating window can be moved".
    @Test("full screen refuses first, tiled or floating")
    func fullscreenFirst() {
        for floating in [true, false] {
            var cues: [ResizeRefusal] = []
            var frames: [WindowID: CGRect] = [:]
            let core = makeCore(floating: floating) { frames[$0] = $1 }
            core.borders.onResizeRefusal = { cues.append($0) }
            core.state.apply(.windowFullscreenChanged(one, isFullscreen: true))
            frames.removeAll()
            #expect(!core.execute("center_floating").isSuccess)
            #expect(cues == [.fullscreenCannotMove(one)])
            #expect(frames[one] == nil)
        }
    }

    @Test("a floating-mode member is a float")
    func floatingMode() {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore(floating: false) { frames[$0] = $1 }
        core.execute(
            "set_mode",
            args: [.string("1"), .string("floating")]
        )
        frames.removeAll()
        #expect(core.execute("center_floating").isSuccess)
        #expect(frames[one]?.midX == screen.midX)
    }

    @Test("float_placement keep still centres, memory untouched")
    func keepCentres() {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.tiler.settings.floatPlacement = .keep
        let saved = StateCoordinator.FloatFrame(
            pid: 900_001,
            frame: CGRect(x: 5, y: 5, width: 100, height: 100)
        )
        core.state.floatFrames[one] = saved
        #expect(core.execute("center_floating").isSuccess)
        #expect(frames[one]?.midX == screen.midX)
        #expect(frames[one]?.size == start.size)
        #expect(core.state.floatFrames[one] == saved)
    }

    @Test("a second press on a centred window writes nothing")
    func alreadyCentred() {
        var writes = 0
        let core = makeCore { _, _ in writes += 1 }
        core.state.apply(
            .windowResized(
                one,
                FloatPlacement.centered(start.size, in: screen)
            )
        )
        #expect(core.execute("center_floating").isSuccess)
        #expect(writes == 0)
    }

    @Test("a drag holding the window stands the verb down")
    func dragStandsDown() {
        var cues: [ResizeRefusal] = []
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.borders.onResizeRefusal = { cues.append($0) }
        core.tiler.dragExemptWindow = one
        #expect(core.execute("center_floating").isSuccess)
        #expect(frames[one] == nil)
        #expect(cues.isEmpty)
    }

    @Test("an aspect probe in flight stands the verb down")
    func probeStandsDown() {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.state.floatAspectFlight = .probing(one)
        core.deferred.schedule(.floatAspect, after: .seconds(60)) {}
        defer { core.deferred.cancel(.floatAspect) }
        #expect(core.execute("center_floating").isSuccess)
        #expect(frames[one] == nil)
    }

    /// A float focused over a maximized tile leaves the maximize
    /// standing: a float is no maximize's to end (#2972's amendment).
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
            $0.maximized = Maximize(window: tile)
            $0.focused = one
        }
        #expect(core.execute("center_floating").isSuccess)
        #expect(core.state.workspaces[space]?.maximized?.window == tile)
    }
}
