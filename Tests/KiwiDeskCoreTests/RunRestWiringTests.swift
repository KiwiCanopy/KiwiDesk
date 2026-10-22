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

    @Test("A changed cover arms the restore; a repeat arms nothing")
    func coverChangeArmsOnce() throws {
        let core = makeCore()
        let space = makeSpace(core, focused: 6)
        // The fixture's own retiles drew the cover for the last
        // window; scrolling back to the top changes it.
        core.retile(animated: false)
        let drawn = core.runArm.answered[space]
        try #require(startDummyPan(core))
        core.state.workspaces.focus(WindowID(2), in: space)
        core.pendingZOrderRestore = false
        core.retile(animated: false)
        #expect(core.runArm.answered[space] != drawn)
        #expect(core.pendingZOrderRestore)
        core.pendingZOrderRestore = false
        core.retile(animated: false)
        #expect(!core.pendingZOrderRestore)
    }

    /// The close-return stand-down governs this arm too (#936): a
    /// removal's retile owes the arm to the tail instead of
    /// issuing it.
    @Test("A removal's retile holds the arm for the tail")
    func removalHoldsTheArm() throws {
        let core = makeCore()
        let space = makeSpace(core, focused: 6)
        core.retile(animated: false)
        try #require(startDummyPan(core))
        core.state.workspaces.focus(WindowID(2), in: space)
        core.pendingZOrderRestore = false
        let owed = core.holdingRunArm(true) {
            core.retile(animated: false)
        }
        #expect(!core.pendingZOrderRestore)
        #expect(owed)
        // The debt lives no longer than the hold's answer.
        #expect(!core.runArm.owed)
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
