import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `size_floating` (#3554): the size it takes, the centre it keeps,
/// its refusals and the cue on a truncated ask.
@Suite("Size floating", .serialized)
@MainActor
struct FloatSizeCommandTests {
    private let one = WindowID(1)
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let start = CGRect(x: 300, y: 200, width: 400, height: 300)

    /// Space 1 with w1 focused at `start`, floating when asked. The
    /// engine is off, so a write lands on the `apply` hook.
    private func makeCore(
        floating: Bool = true,
        applied: @escaping @MainActor (WindowID, CGRect) -> Void
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-fsc-\(UUID().uuidString)")
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
        core.tiler.animation.apply = { id, frame, _ in applied(id, frame) }
        return core
    }

    private func size(_ width: Double, _ height: Double) -> [JSONValue] {
        [.number(width), .number(height)]
    }

    @Test("sizes to the asked points, keeping the centre")
    func asked() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        #expect(
            core.execute("size_floating", args: size(600, 450)).isSuccess
        )
        let frame = try #require(frames[one])
        #expect(frame.size == CGSize(width: 600, height: 450))
        #expect(frame.midX == start.midX)
        #expect(frame.midY == start.midY)
    }

    @Test("no arguments takes float_size, else the derived size")
    func defaults() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.tiler.settings.floatSize = FloatSize(width: 700, height: 500)
        #expect(core.execute("size_floating").isSuccess)
        #expect(frames[one]?.size == CGSize(width: 700, height: 500))
        core.tiler.settings.floatSize = nil
        #expect(core.execute("size_floating").isSuccess)
        let region = try #require(core.floatGrowBounds(on: SpaceID(1)))
        #expect(
            frames[one]?.size == FloatPlacement.derivedSize(in: region)
        )
    }

    @Test("a malformed size refuses and moves nothing")
    func malformed() {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        for bad in [size(0, 450), [.number(600)], size(600, .infinity)] {
            #expect(!core.execute("size_floating", args: bad).isSuccess)
        }
        #expect(frames.isEmpty)
    }

    @Test("a tiled focus refuses with a pill")
    func tiledRefuses() {
        var cues: [ResizeRefusal] = []
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore(floating: false) { frames[$0] = $1 }
        core.borders.onResizeRefusal = { cues.append($0) }
        frames.removeAll()
        #expect(
            !core.execute("size_floating", args: size(600, 450))
                .isSuccess
        )
        #expect(cues == [.moveNeedsFloat(one)])
        #expect(frames[one] == nil)
    }

    @Test("full screen refuses first")
    func fullscreenRefuses() {
        var cues: [ResizeRefusal] = []
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.borders.onResizeRefusal = { cues.append($0) }
        core.state.apply(.windowFullscreenChanged(one, isFullscreen: true))
        frames.removeAll()
        #expect(
            !core.execute("size_floating", args: size(600, 450))
                .isSuccess
        )
        #expect(cues == [.fullscreenCannotMove(one)])
        #expect(frames[one] == nil)
    }

    @Test("an ask the region truncates cues, and lands inside it")
    func truncationCues() throws {
        var cues: [ResizeRefusal] = []
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.borders.onResizeRefusal = { cues.append($0) }
        #expect(
            core.execute("size_floating", args: size(5000, 450)).isSuccess
        )
        let region = try #require(core.floatGrowBounds(on: SpaceID(1)))
        let frame = try #require(frames[one])
        #expect(frame.width == region.width)
        #expect(region.contains(frame))
        #expect(cues == [.ownMaximum(one, axis: "x", atBoundary: true)])
    }

    @Test("a too-tall ask cues on the y axis")
    func truncationCuesHeight() throws {
        var cues: [ResizeRefusal] = []
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.borders.onResizeRefusal = { cues.append($0) }
        #expect(
            core.execute("size_floating", args: size(600, 5000)).isSuccess
        )
        let region = try #require(core.floatGrowBounds(on: SpaceID(1)))
        #expect(frames[one]?.height == region.height)
        #expect(cues == [.ownMaximum(one, axis: "y", atBoundary: true)])
    }

    @Test("an ask that fits draws no cue")
    func fitIsQuiet() {
        var cues: [ResizeRefusal] = []
        let core = makeCore { _, _ in }
        core.borders.onResizeRefusal = { cues.append($0) }
        #expect(
            core.execute("size_floating", args: size(600, 450)).isSuccess
        )
        #expect(cues.isEmpty)
    }

    /// A corroborated bound for w1: two distinct asks, one answer.
    private func seedBound(
        _ core: KiwiCore,
        width: (asks: [CGFloat], answer: CGFloat),
        height: (asks: [CGFloat], answer: CGFloat)
    ) {
        var ledger = SizeBoundLearner.Ledger()
        ledger.width = width.asks.map {
            EffectiveSizeBound.Axis(asked: $0, answered: width.answer)
        }
        ledger.height = height.asks.map {
            EffectiveSizeBound.Axis(asked: $0, answered: height.answer)
        }
        core.tiler.boundLearner.bounds[one] = ledger
    }

    @Test("a learned app ceiling caps the ask, cues it, then is forgotten")
    func ceilingCues() throws {
        var cues: [ResizeRefusal] = []
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.borders.onResizeRefusal = { cues.append($0) }
        seedBound(
            core,
            width: ([1200, 1000], 700),
            height: ([1200, 1000], 500)
        )
        #expect(
            core.execute("size_floating", args: size(900, 450)).isSuccess
        )
        #expect(frames[one]?.size == CGSize(width: 700, height: 450))
        #expect(cues == [.ownMaximum(one, axis: "x", atBoundary: false)])
        #expect(core.tiler.sizeBound(for: one) == nil)
    }

    @Test("an ask under the window's floor is raised to it and cues")
    func floorCues() throws {
        var cues: [ResizeRefusal] = []
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.borders.onResizeRefusal = { cues.append($0) }
        core.execute("set_min_window_size", args: [.number(300)])
        let floor = core.plannedMinSize(of: one, axis: "x")
        #expect(floor >= 300)
        #expect(
            core.execute("size_floating", args: size(100, 450)).isSuccess
        )
        #expect(frames[one]?.width == CGFloat(floor))
        #expect(cues.count == 1)
        if case .ownMinimum(let window, let axis, _) = cues.first {
            #expect(window == one)
            #expect(axis == "x")
        } else {
            Issue.record("expected an own-minimum cue, got \(cues)")
        }
    }

    @Test("a locked app's ask is fitted to its ratio")
    func lockedRatio() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.state.floatAspects[one] = .init(pid: 900_001, ratio: 2)
        #expect(
            core.execute("size_floating", args: size(800, 800)).isSuccess
        )
        // Written at once, so it reaches the applier, not the spring.
        #expect(frames[one] == nil)
        #expect(
            core.tiler.commandedFrame(of: one)?.size
                == CGSize(width: 800, height: 400)
        )
    }
}
