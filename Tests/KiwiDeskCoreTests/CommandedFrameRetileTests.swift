import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An event retile reads where a window IS from the last frame
/// sent ahead of an echo-lagged state frame (#1912): a window an
/// instant switch just placed is neither re-asked nor animated
/// in from the stash corner its state still reads. The ask
/// ledger's clock is frozen by `makeTestCore` (#1456); display
/// pinned (#531). A slide needs a display link, so a host with
/// no screen skips.
@Suite("Retile starts from the frame sent (#1912)", .serialized)
@MainActor
struct CommandedFrameRetileTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let corner = CGRect(x: 1199, y: 752, width: 600, height: 800)

    /// One window parked at the corner by the state's reading,
    /// then placed by an instant re-issuing pass whose echo has
    /// not landed. Returns the slot it was sent to.
    private func placedUnechoed(_ core: KiwiCore) throws -> CGRect {
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.state.apply(
            .windowCreated(ManagedWindow(id: w1, pid: 1, appName: "A"))
        )
        core.state.apply(.windowResized(w1, corner))
        core.tiler.retile(
            state: core.state,
            animated: false,
            pass: .reissue
        )
        return try #require(core.tiler.recentInstantTarget(w1))
    }

    /// Where `id`'s running animation stands, nil if none runs.
    private func animatedFrame(
        _ core: KiwiCore,
        _ id: WindowID
    ) -> CGRect? {
        core.tiler.animation.animations.values
            .compactMap { $0[id]?.frame }.first
    }

    @Test(
        "A window just placed is not re-asked by the next event pass",
        .enabled(if: NSScreen.main != nil)
    )
    func placedWindowIsSkipped() throws {
        let core = makeTestCore()
        defer { core.tiler.animation.cancelAll(snapToTargets: false) }
        _ = try placedUnechoed(core)
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        core.tiler.retile(state: core.state, animated: true)
        #expect(core.tiler.animation.targetFrame(window: w1) == nil)
        #expect(meter.snapshot(reset: false).counts.framesSkipped == 1)
    }

    @Test(
        "A move after an unanswered set slides from that set",
        .enabled(if: NSScreen.main != nil)
    )
    func moveStartsFromTheFrameSent() throws {
        let core = makeTestCore()
        defer { core.tiler.animation.cancelAll(snapToTargets: false) }
        _ = try #require(NSScreen.main?.kiwiDisplay)
        let slot = try placedUnechoed(core)
        // A second window re-slots the first one.
        core.state.apply(
            .windowCreated(ManagedWindow(id: w2, pid: 2, appName: "B"))
        )
        core.tiler.retile(state: core.state, animated: true)
        let start = try #require(
            animatedFrame(core, w1),
            "the re-slot did not animate"
        )
        #expect(TilingEngine.close(start, to: slot))
        #expect(!TilingEngine.close(start, to: corner))
    }

    @Test(
        "A settled slide is not vouched for by the set it replaced",
        .enabled(if: NSScreen.main != nil)
    )
    func slideRetiresTheInstantSet() throws {
        // Instant set to A, slide to B settling with no echo,
        // then the layout asks A again: the window is at B, so
        // the pass must issue rather than skip on the old set.
        let core = makeTestCore()
        defer { core.tiler.animation.cancelAll(snapToTargets: false) }
        _ = try #require(NSScreen.main?.kiwiDisplay)
        let slotA = try placedUnechoed(core)
        let slotB = slotA.offsetBy(dx: 100, dy: 0)
        core.tiler.applyFrame(w1, from: slotA, to: slotB, animated: true)
        #expect(core.tiler.recentInstantTarget(w1) == nil)
        // The slide lands; no echo reaches the state.
        core.tiler.animation.cancelAll(snapToTargets: false)
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        core.tiler.retile(state: core.state, animated: false)
        #expect(meter.snapshot(reset: false).counts.framesIssued == 1)
    }
}
