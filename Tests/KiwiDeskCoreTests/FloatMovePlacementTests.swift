import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A tiled window a move verb files into a floating Space takes
/// the float placement (#1708) — its frame was the layout's slot,
/// often a scrolled-out column's — and a centred placement steps
/// off a spot another float of that Space already holds, for the
/// float verbs alike.
@Suite("Float placement on a move into a floating Space", .serialized)
@MainActor
struct FloatMovePlacementTests {
    /// A scrolled-out column: partly past the screen's left edge.
    private let slot = CGRect(x: -300, y: 60, width: 600, height: 900)
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    /// Space 1 in scrolling with w1 and w2 (w2 focused at `slot`),
    /// Space 2 floating and unshown. The animation engine is off so
    /// a relayout lands synchronously on the `apply` hook.
    private func setup(
        applied: @escaping @MainActor (WindowID, CGRect) -> Void = {
            _,
            _ in
        }
    ) -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        // Pin the display (#531): the region is read through it.
        let screen = self.screen
        core.tiler.visibleBounds = { _ in screen }
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.execute(
            "set_mode",
            args: [.string("2"), .string("floating")]
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
        core.state.apply(.windowResized(WindowID(1), slot))
        core.state.apply(.windowResized(WindowID(2), slot))
        core.state.apply(.windowFocused(WindowID(2)))
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
        return core
    }

    private func centred(_ core: KiwiCore) throws -> CGRect {
        let region = try #require(core.floatGrowBounds(on: SpaceID("2")))
        return FloatPlacement.centered(in: region)
    }

    // MARK: - The move verb

    @Test("a tiled window moved into an unshown floating Space is centred")
    func moveCentres() throws {
        let core = setup()
        #expect(
            core.execute("move_to_space", args: [.string("2")]).isSuccess
        )
        #expect(core.state.workspaces.space(of: WindowID(2)) == SpaceID("2"))
        #expect(core.tiler.stashOriginal(WindowID(2)) == (try centred(core)))
    }

    @Test("a follow delivers the centred frame on the shown Space")
    func followDelivers() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        #expect(core.tiler.recentInstantTarget(WindowID(2)) == nil)
        #expect(
            core.execute(
                "move_to_space_and_follow",
                args: [.string("2")]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        // The restore delivers through the instant set.
        #expect(frames[WindowID(2)] == nil)
        #expect(
            core.tiler.recentInstantTarget(WindowID(2))
                == (try centred(core))
        )
    }

    @Test("a second window moved in cascades off the first")
    func secondMoveCascades() throws {
        let core = setup()
        #expect(
            core.execute("move_to_space", args: [.string("2")]).isSuccess
        )
        core.state.apply(.windowFocused(WindowID(1)))
        #expect(
            core.execute("move_to_space", args: [.string("2")]).isSuccess
        )
        let step = FloatPlacement.cascadeStep
        #expect(
            core.tiler.stashOriginal(WindowID(1))
                == (try centred(core)).offsetBy(dx: step, dy: step)
        )
    }

    @Test("a window already floating keeps its own frame")
    func floatKeepsItsFrame() {
        let core = setup()
        core.state.setFloating(WindowID(2), true)
        #expect(
            core.execute("move_to_space", args: [.string("2")]).isSuccess
        )
        // Parked from where it was: the capture is its own frame.
        #expect(core.tiler.stashOriginal(WindowID(2)) == slot)
    }

    @Test("keep leaves a moved window where the layout had it")
    func keepLeavesIt() {
        let core = setup()
        #expect(
            core.execute(
                "set_float_placement",
                args: [.string("keep")]
            ).isSuccess
        )
        #expect(
            core.execute("move_to_space", args: [.string("2")]).isSuccess
        )
        #expect(core.tiler.stashOriginal(WindowID(2)) == slot)
    }

    @Test("a dragged window keeps the pointer's placement")
    func draggedWindowStandsDown() {
        let core = setup()
        core.tiler.dragExemptWindow = WindowID(2)
        core.moveWindow(WindowID(2), to: SpaceID("2"), follow: false)
        #expect(core.state.workspaces.space(of: WindowID(2)) == SpaceID("2"))
        #expect(core.tiler.stashOriginal(WindowID(2)) != (try? centred(core)))
    }

    /// Asserts on a ledger entry only the forget clears: the move's
    /// own park retires the open ask whatever the placement did.
    @Test("the move's placement forgets the size-bound ledger")
    func moveForgetsTheLedger() {
        let core = setup()
        var ledger = SizeBoundLearner.Ledger()
        ledger.width = [300, 500].map {
            EffectiveSizeBound.Axis(asked: $0, answered: 700)
        }
        core.tiler.boundLearner.bounds[WindowID(2)] = ledger
        #expect(
            core.execute("move_to_space", args: [.string("2")]).isSuccess
        )
        #expect(core.tiler.boundLearner.bounds[WindowID(2)] == nil)
    }

    @Test("a native-fullscreen window is never seeded")
    func fullscreenStandsDown() throws {
        let core = setup()
        core.state.apply(
            .windowFullscreenChanged(WindowID(2), isFullscreen: true)
        )
        core.moveWindow(WindowID(2), to: SpaceID("2"), follow: false)
        #expect(core.state.workspaces.space(of: WindowID(2)) == SpaceID("2"))
        #expect(core.tiler.stashOriginal(WindowID(2)) != (try centred(core)))
    }

    @Test("a move returns a window to its remembered float frame")
    func moveTakesTheRememberedFrame() throws {
        let core = setup()
        // The same-screen judgement reads the topology seam.
        let screen = self.screen
        core.tiler.allScreenBounds = { [screen] }
        let region = try #require(core.floatGrowBounds(on: SpaceID("2")))
        let saved = CGRect(
            x: region.minX + 40,
            y: region.minY + 40,
            width: 500,
            height: 400
        )
        core.state.floatFrames[WindowID(2)] = .init(pid: 1, frame: saved)
        #expect(
            core.execute("move_to_space", args: [.string("2")]).isSuccess
        )
        #expect(core.tiler.stashOriginal(WindowID(2)) == saved)
        #expect(core.state.floatFrames[WindowID(2)] == nil)
    }

    // MARK: - The float verbs cascade too

    @Test("toggle_floating cascades off a float already at the centre")
    func toggleCascades() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        #expect(core.execute("toggle_floating").isSuccess)
        let first = try #require(frames[WindowID(2)])
        // The echo the applier would deliver.
        core.state.apply(.windowResized(WindowID(2), first))
        core.state.apply(.windowFocused(WindowID(1)))
        #expect(core.execute("toggle_floating").isSuccess)
        // w1 is centred at its own (learned) size, then stepped
        // off w2's centre.
        let second = try #require(frames[WindowID(1)])
        let step = FloatPlacement.cascadeStep
        #expect(second.midX == first.midX + step)
        #expect(second.midY == first.midY + step)
    }
}
