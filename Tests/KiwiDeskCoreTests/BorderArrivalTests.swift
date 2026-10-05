import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #1959: after a Space switch the focused ring appears with its
/// window — on the window's first own report near the frame we
/// sent, or at the cap — and never before the slide's plates lift.
/// Driven on a real ring panel; the hold's clock and scheduler are
/// stepped by hand.
@Suite("Border ring arrival (#1959)")
@MainActor
struct BorderArrivalTests {
    private let rest = CGRect(x: 0, y: 0, width: 400, height: 300)
    private let corner = CGRect(x: 1700, y: 1000, width: 400, height: 300)

    /// A manager whose clock reads `now` and whose checks queue up
    /// in `due` instead of running.
    private final class Clock {
        var now: CFTimeInterval = 100
        /// The slide's lift, for the gate case.
        var lift: CFTimeInterval = 0
        /// The engine's commanded frame, for the stale-echo case.
        var commanded: CGRect?
        var due: [(at: CFTimeInterval, run: @MainActor () -> Void)] = []

        /// Advances to `t` and runs every check due by then.
        @MainActor func advance(to t: CFTimeInterval) {
            now = t
            let ready = due.filter { $0.at <= t }
            due.removeAll { $0.at <= t }
            for check in ready { check.run() }
        }
    }

    private func manager(_ clock: Clock) -> BorderManager {
        let border = BorderManager()
        border.movePanel = { _, _ in false }
        border.reduceMotion = { true }
        border.arrivalClock = { clock.now }
        border.scheduleArrivalCheck = { delay, run in
            clock.due.append((clock.now + delay, run))
        }
        return border
    }

    private func spec() -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(1),
            frame: rest,
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
    }

    /// The ring shown, then retired with its Space, then held for
    /// the switch back and synced: ordered in, still dormant.
    private func heldRing(
        _ border: BorderManager,
        notBefore: @escaping @MainActor () -> CFTimeInterval? = { nil }
    ) throws -> AppKitBorderOverlay {
        border.sync([spec()])
        border.sync([])
        border.holdArrival(of: WindowID(1), notBefore: notBefore)
        border.sync([spec()])
        let ring = try #require(border.overlays[WindowID(1)])
        return try #require(ring.backend as? AppKitBorderOverlay)
    }

    private func report(_ border: BorderManager, _ frame: CGRect) {
        border.follow(
            WindowID(1),
            windowFrame: frame,
            source: .axEcho,
            pin: nil
        )
    }

    @Test("a held ring waits for its window's report near the target")
    func reportNearTargetReveals() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        let panel = try heldRing(border)
        #expect(panel.panelAlpha == 0)
        #expect(panel.isOrderedIn)
        report(border, corner)
        #expect(panel.panelAlpha == 0, "a report off target is no arrival")
        report(border, rest.offsetBy(dx: 2, dy: -3))
        #expect(panel.panelAlpha == 1)
        #expect(border.arrival == nil)
    }

    /// Device, 2026-10-05: the state frame (the spec) still read
    /// the corner, and a stale corner echo had already retired the
    /// commanded frame when the window landed — the hold keeps the
    /// frame the switch sent.
    @Test("the landing frame is kept past a stale echo")
    func landingFrameOutlivesTheEcho() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        clock.commanded = rest
        border.commandedFrame = { _ in clock.commanded }
        let stale = BorderManager.Spec(
            window: WindowID(1),
            frame: corner,
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
        border.sync([stale])
        border.sync([])
        border.holdArrival(of: WindowID(1))
        border.sync([stale])
        let ring = try #require(border.overlays[WindowID(1)])
        let panel = try #require(ring.backend as? AppKitBorderOverlay)
        report(border, corner)
        clock.commanded = nil
        #expect(panel.panelAlpha == 0)
        report(border, rest)
        #expect(panel.panelAlpha == 1)
    }

    @Test("a window that never reports gets its ring at the cap")
    func capRevealsASilentWindow() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        let panel = try heldRing(border)
        clock.advance(to: 100 + BorderManager.arrivalCap / 2)
        #expect(panel.panelAlpha == 0)
        clock.advance(to: 100 + BorderManager.arrivalCap)
        #expect(panel.panelAlpha == 1)
    }

    @Test("an arrived window waits for the plates to lift")
    func liftGatesTheReveal() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        clock.lift = 100.4
        let panel = try heldRing(border) { clock.lift }
        report(border, rest)
        #expect(panel.panelAlpha == 0)
        // A burst press moves the lift later before it comes.
        clock.lift = 100.6
        clock.advance(to: 100.4)
        #expect(panel.panelAlpha == 0)
        clock.advance(to: 100.6)
        #expect(panel.panelAlpha == 1)
    }

    /// The switch's own raise fires a reorder and an unhide; the
    /// order they ask for must not show the ring early — the one
    /// path the device found leading by ~300 ms.
    @Test(
        "a reorder or unhide keeps a held ring dormant",
        arguments: [
            SkyLightWindowEvents.Kind.reorder, .unhide,
        ]
    )
    func windowServerOrderKeepsTheHold(
        kind: SkyLightWindowEvents.Kind
    ) throws {
        let clock = Clock()
        let border = manager(clock)
        border.readWindowBounds = { [corner] _ in corner }
        defer { border.clear() }
        let panel = try heldRing(border)
        border.handleSkyLightEvent(kind, window: WindowID(1))
        #expect(panel.panelAlpha == 0)
        #expect(panel.isOrderedIn)
    }

    @Test("our own animation ticks are not the window arriving")
    func animationTickIsNoArrival() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        let panel = try heldRing(border)
        border.follow(
            WindowID(1),
            windowFrame: rest,
            source: .animationTick,
            pin: nil
        )
        #expect(panel.panelAlpha == 0)
    }

    @Test("a ring already showing is never held")
    func shownRingIsNotHeld() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        border.sync([spec()])
        border.holdArrival(of: WindowID(1))
        border.sync([spec()])
        let ring = try #require(border.overlays[WindowID(1)])
        let panel = try #require(ring.backend as? AppKitBorderOverlay)
        #expect(panel.panelAlpha == 1)
        #expect(border.arrival == nil)
    }

    @Test("a Space switch holds the arriving Space's focused ring")
    func switchHoldsTheAnchor() {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for (id, space) in [(WindowID(1), 1), (WindowID(2), 2)] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "A")
                )
            )
            core.state.workspaces.add(id, to: SpaceID(space))
        }
        core.state.workspaces.stampFocus(WindowID(2), in: SpaceID(2))
        core.retile()
        core.borders.scheduleArrivalCheck = { _, _ in }
        core.execute("focus_space", args: [.string("2")])
        #expect(core.borders.arrival?.window == WindowID(2))
    }
}
