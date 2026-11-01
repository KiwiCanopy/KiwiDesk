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

    /// Awaits the slot until it stops re-arming: the body takes
    /// two quiet looks before it runs.
    private func payOwedPass(_ core: KiwiCore) async throws {
        var owed = try #require(core.deferred.task(for: .applyHealPass))
        for _ in 0..<10 {
            await owed.value
            guard let next = core.deferred.task(for: .applyHealPass),
                next != owed
            else { return }
            owed = next
        }
        Issue.record("the apply heal pass kept re-arming")
    }

    private func ratio(_ core: KiwiCore, _ space: SpaceID) -> Double {
        core.tiler.settings.resolvedStack(
            for: core.state.workspaces[space]!,
            flip: nil
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
        try await payOwedPass(core)
        #expect(ratio(core, space) < 0.6)
        let frame = try #require(
            core.tiler.calculatedFrames(state: core.state)[WindowID(2)]
        )
        #expect(frame.width >= 700)
    }

    /// The body waits out an animation still landing the apply's
    /// frames, and one quiet look after it, re-arming rather than
    /// healing over the settle probe's read.
    @Test("The pass waits for the apply's frames to land")
    func waitsOutTheAnimation() throws {
        let (core, space) = makeHealedCore()
        core.execute("stack.set_master_ratio", args: [.number(0.6)])
        core.deferred.cancel(.applyHealPass)
        core.deferred.sleep = { _ in
            try? await Task.sleep(for: .seconds(3600))
        }
        let screen = try #require(NSScreen.main)
        core.tiler.animation.animate(
            window: WindowID(1),
            on: screen,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 800, y: 0, width: 100, height: 100)
        )
        #expect(core.tiler.animation.activeCount > 0)
        let later = ContinuousClock.now + .seconds(60)
        // Moving, then the first quiet look: neither runs it.
        core.payApplyHealPass(until: later, restedAtLastLook: true)
        #expect(core.deferred.isScheduled(.applyHealPass))
        #expect(ratio(core, space) == 0.6)
        core.tiler.animation.cancel(window: WindowID(1))
        core.payApplyHealPass(until: later, restedAtLastLook: false)
        #expect(ratio(core, space) == 0.6)
        core.payApplyHealPass(until: later, restedAtLastLook: true)
        #expect(ratio(core, space) < 0.6)
        // The hour-long sleeps the pass's tail scheduled.
        core.deferred.cancelAll()
    }

    /// A window that never stops moving cannot hold the pass past
    /// its deadline.
    @Test("The deadline runs the pass whatever is owed")
    func deadlineRunsThePass() throws {
        let (core, space) = makeHealedCore()
        core.execute("stack.set_master_ratio", args: [.number(0.6)])
        core.deferred.cancel(.applyHealPass)
        let screen = try #require(NSScreen.main)
        core.tiler.animation.animate(
            window: WindowID(1),
            on: screen,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 800, y: 0, width: 100, height: 100)
        )
        #expect(core.applyFramesLanding())
        core.payApplyHealPass(
            until: .now - .seconds(1),
            restedAtLastLook: false
        )
        #expect(!core.deferred.isScheduled(.applyHealPass))
        #expect(ratio(core, space) < 0.6)
        core.tiler.animation.cancel(window: WindowID(1))
        core.deferred.cancelAll()
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
