import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `reset_layout_sizing` records its track restore for the
/// dispatcher's retile (#764, #153) — the `ZOrderScheduleTests`
/// ▸ `stackPromoteDefersRestore` shape: frames settled, the verb
/// run, and the restore STILL pending after the dispatcher's
/// retile started its animations. An arm on the spot is
/// consumed before those animations begin and reads `false`
/// here; a gate that never fires reads `false` too. The pile is
/// `trackSwapSchedulesRestore`'s. Display pinned (#531); a
/// headless host is a SKIP.
@Suite(
    "reset_layout_sizing z-order restore (#764)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ResetLayoutSizingZOrderTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
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

    @Test("An overflowing track keeps the restore pending past the retile")
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
        // A weight the reset clears, so the dispatcher's retile
        // has frames to animate.
        core.state.workspaces.withSpace(space) {
            $0.trackWeights[WindowID(1)] = 3
        }
        settle(core)
        #expect(core.activeTrackOverflows)
        #expect(core.execute("reset_layout_sizing").isSuccess)
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(!core.pendingZOrderRestore)
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
