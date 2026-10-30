import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An explicit apply owes one ordinary pass (#2785): its own pass
/// probes, so the split floor heal stands down on it, and where
/// every bound is already learned no answer retiles. The device
/// case was a Settings Save with every minimum learned; here the
/// apply is `stack.set_master_ratio`, which reseeds the session
/// ratio the same way. Display and `min_window_size` pinned (#531).
@Suite(
    "An apply owes its heal pass (#2785)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ApplyHealPassTests {
    /// Master w1 and stack w2 in a Stack Space on a pinned
    /// 1200×800 display, w2's refusal of a 400 pt width learned
    /// and healed.
    private func makeHealedCore() -> (KiwiCore, SpaceID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-apply-heal-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        core.deferred.sleep = { _ in }
        // Instant frames: the body pays at once, never re-arming
        // behind an animation the runner may not tick.
        core.tiler.settings.animations.onRelayout = false
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_300 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        core.tiler.boundLearner.bounds[WindowID(2)] = .init(width: [
            .init(asked: 400, answered: 700)
        ])
        core.retile()
        return (core, space)
    }

    private func ratio(_ core: KiwiCore, _ space: SpaceID) -> Double {
        core.tiler.settings.resolvedStack(
            for: core.state.workspaces[space]!
        ).masterRatio
    }

    @Test("The pass after an apply heals the reseeded split")
    func applyHealsOnItsOwnPass() async throws {
        let (core, space) = makeHealedCore()
        #expect(ratio(core, space) < 0.6)
        core.execute("stack.set_master_ratio", args: [.number(0.6)])
        // The apply's own pass drew the reseeded ratio: the heal
        // stood down on its probe.
        #expect(ratio(core, space) == 0.6)
        let owed = try #require(core.deferred.task(for: .applyHealPass))
        await owed.value
        #expect(ratio(core, space) < 0.6)
        let frame = try #require(
            core.tiler.calculatedFrames(state: core.state)[WindowID(2)]
        )
        #expect(frame.width >= 700)
    }

    @Test("An ordinary pass owes none")
    func eventPassOwesNothing() {
        let (core, _) = makeHealedCore()
        // The fixture's `set_mode` is an apply of its own.
        core.deferred.cancel(.applyHealPass)
        core.retile()
        #expect(!core.deferred.isScheduled(.applyHealPass))
    }
}
