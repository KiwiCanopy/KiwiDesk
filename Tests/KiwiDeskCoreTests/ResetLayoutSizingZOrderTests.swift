import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `reset_layout_sizing` arms its track restore only where the
/// track piles (#764, #153), and the restore waits for the
/// animations in flight. The pile is
/// `trackSwapSchedulesRestore`'s emergency pile; since a scrolled
/// run (#2235) piles nothing, a reset there arms nothing. Display
/// pinned (#531); a headless host is a SKIP.
@Suite(
    "reset_layout_sizing z-order restore (#764)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ResetLayoutSizingZOrderTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-reset-zorder-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id in 1...8 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        return core
    }

    /// Settles every window at its layout target so the only
    /// animations after the verb are the reset's own.
    private func settle(_ core: KiwiCore) {
        core.retile(animated: false)
        for (id, frame) in core.tiler.calculatedFrames(
            state: core.state
        ) {
            core.state.apply(.windowMoved(id, frame))
        }
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(core.tiler.animation.activeCount == 0)
    }

    @Test("A piled track keeps the restore pending past the retile")
    func trackPileDefersRestore() throws {
        let core = makeCore()
        let space = try #require(
            core.state.workspaces.space(of: WindowID(1))
        )
        _ = core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        _ = core.execute(
            "track.set_limit",
            args: [.number(Double(TrackParams.minLimit))]
        )
        // Not one window keeps a 900 pt minimum in 800 pt: the
        // emergency whole-zone pile, the one track pile a scrolled
        // run leaves (#2235). Its frames ignore the weights, so a
        // pan holds the restore pending.
        _ = core.execute("set_min_window_size", args: [.number(900)])
        core.state.workspaces.withSpace(space) {
            $0.trackWeights[WindowID(1)] = 3
        }
        settle(core)
        #expect(core.activeTrackOverflows)
        try #require(startDummyPan(core))
        #expect(core.execute("reset_layout_sizing").isSuccess)
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(!core.pendingZOrderRestore)
    }

    /// A scrolled run parks what it hides and piles nothing, so a
    /// reset owes it no restore (#2235).
    @Test("A scrolled track arms nothing")
    func scrolledTrackArmsNothing() throws {
        let core = makeCore()
        let space = try #require(
            core.state.workspaces.space(of: WindowID(1))
        )
        _ = core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("track")]
        )
        _ = core.execute(
            "track.set_limit",
            args: [.number(Double(TrackParams.minLimit))]
        )
        settle(core)
        #expect(!core.runHidden.isEmpty)
        #expect(!core.activeTrackOverflows)
        try #require(startDummyPan(core))
        #expect(core.execute("reset_layout_sizing").isSuccess)
        #expect(!core.pendingZOrderRestore)
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

    @Test("A stack Space arms nothing")
    func stackSpaceArmsNothing() throws {
        let core = makeCore()
        let space = try #require(
            core.state.workspaces.space(of: WindowID(1))
        )
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        core.state.workspaces.withSpace(space) {
            $0.stackWeights[WindowID(2)] = 3
        }
        settle(core)
        #expect(!core.activeTrackOverflows)
        #expect(core.execute("reset_layout_sizing").isSuccess)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
