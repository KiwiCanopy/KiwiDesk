import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The run arm's production wiring (#2235): a removal driven
/// through `handle` — inline or folded into a Desktop switch's
/// re-sync — owes its arm to the close-return tail, which pays it
/// where the raise runs and stands it down where the raise does
/// (#936); a focus report onto a hidden window scrolls the run;
/// and a change that moves no window between layers arms nothing.
/// `.enabled(if:)` because the dummy pan needs a real `NSScreen`.
@Suite(
    "Run arm wiring (#2235)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunArmWiringTests {
    /// Six windows in one stack Space, focus on window 6: the run
    /// shows the zone's tail and 2…4 wait behind it.
    private func makeCore() -> (KiwiCore, SpaceID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-run-arm-\(UUID().uuidString)"
                )
        )
        // Pinned (tests.md, #531): whether the stack overflows is
        // what the suite reads.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
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
        _ = core.execute("set_min_window_size", args: [.number(300)])
        core.state.workspaces.focus(WindowID(6), in: space)
        core.retile(animated: false)
        return (core, space)
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

    /// Closes the focused window 6, so the focus — and the run —
    /// moves to window 5; `folded` runs it inside a re-sync.
    private func closeFocused(
        _ core: KiwiCore,
        _ space: SpaceID,
        folded: Bool
    ) throws -> Bool {
        let before = try #require(core.tiler.runCovers[space])
        try #require(startDummyPan(core))
        core.pendingZOrderRestore = false
        let close = {
            core.handle(.windowDestroyed(WindowID(6), wasMinimized: false))
        }
        if folded {
            core.foldingSwitchResync(close)
        } else {
            close()
        }
        let after = try #require(core.tiler.runCovers[space])
        #expect(after.stacking != before.stacking)
        return core.pendingZOrderRestore
    }

    @Test("A close's arm is paid where the raise runs")
    func closePaysTheArm() throws {
        let (core, space) = makeCore()
        #expect(try closeFocused(core, space, folded: false))
    }

    @Test("A close's arm stands down with the raise (#936)")
    func closeStandsTheArmDown() throws {
        let (core, space) = makeCore()
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 42, isDialog: true)
        }
        #expect(try !closeFocused(core, space, folded: false))
    }

    @Test("A folded close's arm is paid after the re-sync's pass")
    func foldedClosePaysTheArm() throws {
        let (core, space) = makeCore()
        #expect(try closeFocused(core, space, folded: true))
    }

    @Test("A folded close's arm stands down with the raise")
    func foldedCloseStandsTheArmDown() throws {
        let (core, space) = makeCore()
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 42, isDialog: true)
        }
        #expect(try !closeFocused(core, space, folded: true))
    }

    @Test("A focus report onto a hidden window scrolls the run")
    func focusReportScrollsTheRun() throws {
        let (core, space) = makeCore()
        let before = try #require(core.tiler.runCovers[space])
        #expect(before.behind[WindowID(2)] != nil)
        core.handle(.windowFocused(WindowID(2)))
        #expect(core.activeSpace?.focused == WindowID(2))
        let after = try #require(core.tiler.runCovers[space])
        #expect(after.behind[WindowID(2)] == nil)
    }

    /// The arm compares what decides the stacking, never the
    /// run's weight span, which a gap edit moves.
    @Test("A gap edit that keeps the run arms nothing")
    func gapEditArmsNothing() throws {
        let (core, space) = makeCore()
        let before = try #require(core.tiler.runCovers[space])
        try #require(startDummyPan(core))
        core.pendingZOrderRestore = false
        _ = core.execute("set_gap_global", args: [.number(4)])
        let after = try #require(core.tiler.runCovers[space])
        #expect(after != before)
        #expect(after.stacking == before.stacking)
        #expect(!core.pendingZOrderRestore)
    }
}
