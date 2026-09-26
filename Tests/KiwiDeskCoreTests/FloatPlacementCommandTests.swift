import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The float verbs' placement (#1674): a tiled window floated by
/// `toggle_floating` / `make_floating` lands centred at the
/// derived size, `keep` leaves it, and a window already an
/// EFFECTIVE float is never placed (`EffectiveFloat`'s roster).
@Suite("Float placement on the float verbs", .serialized)
@MainActor
struct FloatPlacementCommandTests {
    private let slot = CGRect(x: 40, y: 60, width: 300, height: 900)

    /// Two windows on space 1 in `mode`, w2 focused at `slot`.
    /// The animation engine is disabled so the relayout path
    /// lands synchronously on the observable `apply` hook.
    private func setup(
        mode: String,
        applied: @escaping @MainActor (WindowID, CGRect) -> Void
    ) -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        // Pin the display (#531): the region is read through it.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.execute("set_mode", args: [.string("1"), .string(mode)])
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
        core.state.apply(.windowResized(WindowID(2), slot))
        core.state.apply(.windowFocused(WindowID(2)))
        core.tiler.settings.animations.onRelayout = true
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
        return core
    }

    @Test("toggle_floating centres a tiled window at the derived size")
    func toggleCentres() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "bsp") { frames[$0] = $1 }
        #expect(core.execute("toggle_floating").isSuccess)
        let frame = try #require(frames[WindowID(2)])
        let region = try #require(core.floatGrowBounds(of: WindowID(2)))
        #expect(abs(frame.midX - region.midX) < 0.001)
        #expect(abs(frame.midY - region.midY) < 0.001)
        #expect(
            abs(frame.height - region.height * FloatPlacement.shortShare)
                < 0.001
        )
        #expect(frame.width == FloatPlacement.longFloor)
    }

    @Test("make_floating places too")
    func makeFloatingPlaces() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "stack") { frames[$0] = $1 }
        #expect(core.execute("make_floating").isSuccess)
        #expect(frames[WindowID(2)]?.width == FloatPlacement.longFloor)
    }

    @Test("keep leaves the frame where the layout had it")
    func keepLeavesIt() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "bsp") { frames[$0] = $1 }
        #expect(
            core.execute(
                "set_float_placement",
                args: [.string("keep")]
            ).isSuccess
        )
        #expect(core.tiler.settings.floatPlacement == .keep)
        #expect(core.execute("toggle_floating").isSuccess)
        #expect(frames[WindowID(2)] == nil)
    }

    @Test("a floating-mode member's frame is the user's: no placement")
    func floatingModeMemberStays() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "floating") { frames[$0] = $1 }
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.state.windows[WindowID(2)]?.isFloating == true)
        #expect(frames[WindowID(2)] == nil)
    }

    @Test("an already-floating window is not placed again")
    func alreadyFloatingStays() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "bsp") { frames[$0] = $1 }
        core.state.setFloating(WindowID(2), true)
        #expect(core.execute("make_floating").isSuccess)
        #expect(frames[WindowID(2)] == nil)
    }

    @Test("set_float_placement refuses a value it does not name")
    func refusesUnknown() {
        let core = setup(mode: "bsp") { _, _ in }
        let response = core.execute(
            "set_float_placement",
            args: [.string("nudge")]
        )
        #expect(!response.isSuccess)
        #expect(core.tiler.settings.floatPlacement == .center)
    }

    /// Seeds a corroborated bound for w2 on both axes: two
    /// distinct asks answered with one span.
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
        core.tiler.boundLearner.bounds[WindowID(2)] = ledger
    }

    @Test("a learned app minimum outranks the derived size")
    func learnedMinimumWins() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "bsp") { frames[$0] = $1 }
        seedBound(
            core,
            width: ([300, 500], 900),
            height: ([300, 500], 800)
        )
        #expect(core.tiler.sizeBound(for: WindowID(2))?.minWidth == 900)
        #expect(core.execute("toggle_floating").isSuccess)
        let frame = try #require(frames[WindowID(2)])
        #expect(frame.width == 900)
        #expect(frame.height == 800)
    }

    @Test("a learned app maximum caps the derived size, still centred")
    func learnedMaximumCaps() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "bsp") { frames[$0] = $1 }
        seedBound(
            core,
            width: ([1200, 1000], 400),
            height: ([1200, 1000], 300)
        )
        #expect(core.execute("toggle_floating").isSuccess)
        let frame = try #require(frames[WindowID(2)])
        let region = try #require(core.floatGrowBounds(of: WindowID(2)))
        #expect(frame.width == 400)
        #expect(frame.height == 300)
        #expect(abs(frame.midX - region.midX) < 0.001)
    }

    /// A ∞ traveler from a tiled home, focused on a floating-mode
    /// active space it RENDERS on: its frame there is the user's,
    /// so the gate judges the render space and places nothing.
    @Test("a traveler is judged on the space it renders on")
    func travelerJudgedOnRenderSpace() {
        var frames: [WindowID: CGRect] = [:]
        let core = setup(mode: "bsp") { frames[$0] = $1 }
        let traveler = WindowID(3)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: traveler,
                    pid: 1,
                    appName: "Sticky",
                    frame: slot,
                    stickyScope: .global
                )
            )
        )
        core.state.workspaces.focus(traveler, in: SpaceID("1"))
        let second = SpaceID("2")
        core.state.workspaces.ensureSpace(second)
        core.state.workspaces.setMode(second, .floating)
        core.state.workspaces.activate(second)
        #expect(core.focusedWindowID == traveler)
        #expect(core.floatPlacementSpace(of: traveler) == second)
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.state.windows[traveler]?.isFloating == true)
        #expect(frames[traveler] == nil)
    }
}
