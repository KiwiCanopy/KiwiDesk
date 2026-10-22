import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The retile tail that closes the run loop (#2235): the layout
/// reads `Space.runHeads`, and `persistRunHeads` writes back the
/// heads the pass drew and arms the z-order restore when what the
/// runs hide changed. The layout suites inject heads by hand, so
/// only a real retile sees a deleted wiring line. `.enabled(if:)`
/// because the dummy pan needs a real `NSScreen`.
@Suite(
    "Run rest wiring (#2235)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunRestWiringTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-run-rest-\(UUID().uuidString)"
                )
        )
        // Pinned (tests.md, #531): whether the stack overflows is
        // what the suite reads.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        return core
    }

    /// Six windows in one stack Space, focus on `focused`.
    private func makeSpace(_ core: KiwiCore, focused: UInt32) -> SpaceID {
        for id in 1...6 {
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
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        _ = core.execute(
            "set_min_window_size",
            args: [.number(300)]
        )
        core.state.workspaces.focus(WindowID(focused), in: space)
        return space
    }

    /// Holds a restore pending instead of letting it run.
    private func startDummyPan(_ core: KiwiCore) -> Bool {
        guard let screen = NSScreen.main else { return false }
        core.tiler.animation.animate(
            window: WindowID(999),
            on: screen,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 800, y: 0, width: 100, height: 100)
        )
        return core.tiler.animation.activeCount > 0
    }

    @Test("A retile writes back the head its run rests at")
    func retileWritesTheHead() throws {
        let core = makeCore()
        let space = makeSpace(core, focused: 6)
        core.retile(animated: false)
        let heads = try #require(core.state.workspaces[space]?.runHeads)
        // Focus on the last window scrolled the stack: its head
        // is a stack window past the first.
        #expect(!heads.isEmpty)
        #expect(!heads.contains(WindowID(2)))
        #expect(!heads.contains(WindowID(1)))
    }

    /// Hidden windows rest parked at the hide corner and overlap
    /// nothing (#2235 ruling, 2026-10-22), so a scroll owes no
    /// z-order restore — the pan holds any restore pending, which
    /// is what the assertion reads.
    @Test("A scroll arms no z-order restore")
    func scrollArmsNothing() throws {
        let core = makeCore()
        let space = makeSpace(core, focused: 6)
        core.retile(animated: false)
        let before = try #require(core.tiler.runCovers[space])
        try #require(startDummyPan(core))
        core.state.workspaces.focus(WindowID(2), in: space)
        core.pendingZOrderRestore = false
        core.retile(animated: false)
        let after = try #require(core.tiler.runCovers[space])
        #expect(after.heads != before.heads)
        #expect(!core.pendingZOrderRestore)
    }

    /// The parked windows share one corner frame: the track
    /// restore, which judges a pile by overlap, leaves them out or
    /// every scroll would restack a phantom pile at the corner.
    @Test("The track restore leaves the parked windows out")
    func trackRestoreSkipsParked() throws {
        let core = makeCore()
        let space = makeSpace(core, focused: 6)
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        // One normal track and the overflow track, which shows two
        // of its five.
        _ = core.execute(
            "track.set_limit",
            args: [.number(Double(TrackParams.minLimit))]
        )
        core.retile(animated: false)
        let input = try #require(
            core.tiler.layoutInput(state: core.state)
        )
        let parked = core.parkedByRun(input)
        #expect(!parked.isEmpty)
        #expect(core.trackRestoreOrder(input).isEmpty)
        #expect(!core.activeTrackOverflows)
    }

    @Test("The stack restack leaves the parked windows out")
    func stackRestackSkipsParked() throws {
        let core = makeCore()
        _ = makeSpace(core, focused: 6)
        core.retile(animated: false)
        let hidden = core.runHidden
        #expect(!hidden.isEmpty)
        let zone = (2...6).map { WindowID(UInt32($0)) }
        let order = core.stackRestoreOrder(zone[...])
        #expect(Set(order) == Set(zone).subtracting(hidden))
    }

    /// Focus drives the scroll (#2235 ruling): the focus verb's
    /// step past the run's edge lands on a hidden window, and the
    /// focus itself retiles so the run moves to show it.
    @Test("Focusing a hidden window scrolls the run to it")
    func focusScrollsTheRun() throws {
        let core = makeCore()
        let space = makeSpace(core, focused: 2)
        core.retile(animated: false)
        core.state.workspaces.focus(WindowID(3), in: space)
        core.retile(animated: false)
        let before = try #require(core.tiler.runCovers[space])
        #expect(before.behind[WindowID(4)] != nil)
        #expect(
            core.execute("focus", args: [.string("down")]).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(4))
        let after = try #require(core.tiler.runCovers[space])
        #expect(after.behind[WindowID(4)] == nil)
        #expect(core.state.workspaces[space]?.runHeads == [WindowID(3)])
    }

    /// A run keeps both its ends at rest (owner, 2026-10-22): a
    /// stored tail reaches the layout and is written back, so a
    /// pass adds no window a focus step did not ask for.
    @Test("A retile reads and writes back the run's tail")
    func retileKeepsTheTail() throws {
        let core = makeCore()
        let space = makeSpace(core, focused: 1)
        core.state.workspaces.withSpace(space) {
            $0.runHeads = [WindowID(3)]
            $0.runTails = [WindowID(3)]
        }
        core.retile(animated: false)
        let run = try #require(core.tiler.runCovers[space]?.runs.first)
        // Room for two, yet the stored ends hold the one.
        #expect(Array(run.shown) == [WindowID(3)])
        let stored = try #require(core.state.workspaces[space])
        #expect(stored.runTails == [WindowID(3)])
        // A step to window 4 moves the tail, and the pass writes
        // the new one back.
        core.state.workspaces.focus(WindowID(4), in: space)
        core.retile(animated: false)
        #expect(core.state.workspaces[space]?.runTails == [WindowID(4)])
    }

    /// The device case (owner, 2026-10-22): every window on its
    /// own track, the automatic cap folds them into one overflow
    /// track that scrolls, and a step along that track is ↓ —
    /// never → across tracks the fold merged (#1488).
    @Test("A step along a folded overflow track takes its axis")
    func foldedTrackStepsAlong() throws {
        let core = makeCore()
        let space = makeSpace(core, focused: 2)
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        // After the mode write, which seeds its own partition.
        core.state.workspaces.withSpace(space) {
            $0.trackBreaks = Set((1...6).map { WindowID(UInt32($0)) })
        }
        _ = core.execute("set_min_window_size", args: [.number(600)])
        core.state.workspaces.focus(WindowID(2), in: space)
        core.retile(animated: false)
        #expect(core.runHidden.contains(WindowID(3)))
        #expect(
            core.execute("focus", args: [.string("down")]).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(3))
    }

    @Test("The shown slots leave a run's hidden windows out")
    func shownSlotsDropHidden() throws {
        let core = makeCore()
        _ = makeSpace(core, focused: 2)
        core.retile(animated: false)
        let hidden = core.runHidden
        #expect(!hidden.isEmpty)
        let slots = core.shownSlots()
        #expect(hidden.allSatisfy { slots[$0] == nil })
        #expect(slots[WindowID(2)] != nil)
    }
}
