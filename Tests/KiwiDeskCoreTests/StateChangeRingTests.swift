import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #2676: the ring of a window changing state goes dormant while
/// our spring moves the window and returns once the spring has
/// ended and the window reports near the frame we sent, or the cap
/// passes. Driven on a real ring panel; the clock and the check
/// scheduler are stepped by hand, as `BorderArrivalTests` does.
/// Main-actor spend: one panel per test, no scan.
@Suite("State change ring hold (#2676)")
@MainActor
struct StateChangeRingTests {
    private let rest = CGRect(x: 0, y: 0, width: 400, height: 300)
    private let away = CGRect(x: 600, y: 300, width: 400, height: 300)

    private final class Clock {
        var now: CFTimeInterval = 100
        var due: [(at: CFTimeInterval, run: @MainActor () -> Void)] = []

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

    /// A shown ring, then held for a state change.
    private func heldRing(
        _ border: BorderManager
    ) throws -> AppKitBorderOverlay {
        let panel = try heldRingSpec(border)
        #expect(panel.panelAlpha == 1)
        border.holdStateChange(of: WindowID(1), target: rest)
        return panel
    }

    /// The ring synced at `rest`; shown unless a hold is pending.
    private func heldRingSpec(
        _ border: BorderManager
    ) throws -> AppKitBorderOverlay {
        border.sync([
            BorderManager.Spec(
                window: WindowID(1),
                frame: rest,
                colorHex: "#FF0000",
                width: 4,
                cornerStyle: .rounded
            )
        ])
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

    @Test("a shown ring goes dormant and waits for the settle")
    func reportBeforeSettleKeepsItHeld() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        let panel = try heldRing(border)
        #expect(panel.panelAlpha == 0)
        report(border, rest)
        #expect(panel.panelAlpha == 0, "the spring has not ended")
        border.stateChangeSettled(WindowID(1))
        #expect(panel.panelAlpha == 0, "an early report is no arrival")
        #expect(border.stateChange?.arrived == false)
    }

    @Test("after the settle a report near the target reveals it")
    func reportAfterSettleReveals() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        let panel = try heldRing(border)
        border.stateChangeSettled(WindowID(1))
        report(border, away)
        #expect(panel.panelAlpha == 0, "a report off target")
        report(border, rest)
        #expect(panel.panelAlpha == 1)
        #expect(border.stateChange == nil)
    }

    @Test("a window that never reports gets its ring at the cap")
    func capReveals() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        let panel = try heldRing(border)
        border.stateChangeSettled(WindowID(1))
        clock.advance(to: 100 + BorderManager.arrivalCap / 2)
        #expect(panel.panelAlpha == 0)
        clock.advance(to: 100 + BorderManager.arrivalCap)
        #expect(panel.panelAlpha == 1)
    }

    @Test("an order while held does not show the ring")
    func orderKeepsTheHold() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        let panel = try heldRing(border)
        border.overlays[WindowID(1)]?.order(relativeTo: 1)
        #expect(panel.panelAlpha == 0)
    }

    @Test("a hold no spring end reaches lets go at the backstop")
    func backstopReveals() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        let panel = try heldRing(border)
        clock.advance(to: 100 + BorderManager.arrivalCap)
        #expect(panel.panelAlpha == 0, "the spring may still run")
        clock.advance(to: 100 + BorderManager.stateChangeBackstop)
        #expect(panel.panelAlpha == 1)
    }

    /// The real door: a window our spring moves is held, and the
    /// engine's end of that spring starts the cap.
    @Test("a spring the core starts holds and its end releases")
    func coreDoorHoldsAndEndReleases() throws {
        let clock = Clock()
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-ring-\(UUID().uuidString)"
                )
        )
        let border = core.borders
        border.movePanel = { _, _ in false }
        border.reduceMotion = { true }
        border.arrivalClock = { clock.now }
        border.scheduleArrivalCheck = { delay, run in
            clock.due.append((clock.now + delay, run))
        }
        defer { border.clear() }
        border.sync([
            BorderManager.Spec(
                window: WindowID(1),
                frame: rest,
                colorHex: "#FF0000",
                width: 4,
                cornerStyle: .rounded
            )
        ])
        let ring = try #require(border.overlays[WindowID(1)])
        guard let screen = NSScreen.screens.first else { return }
        core.tiler.animation.isEnabled = true
        core.tiler.animation.animate(
            window: WindowID(1),
            on: screen,
            from: rest,
            to: away
        )
        core.holdRingForStateChange(WindowID(1))
        #expect(ring.isDormant)
        core.tiler.animation.cancel(window: WindowID(1))
        #expect(border.stateChange?.settledAt != nil)
        clock.advance(to: 100 + BorderManager.arrivalCap)
        #expect(!ring.isDormant)
    }

    /// A window with no ring yet — out of the pocket — has the hold
    /// applied by the sync that draws its ring.
    @Test("a hold armed before the ring exists applies at its sync")
    func pendingHoldAppliesAtSync() throws {
        let clock = Clock()
        let border = manager(clock)
        defer { border.clear() }
        border.holdStateChange(of: WindowID(1), target: rest)
        let panel = try heldRingSpec(border)
        #expect(panel.panelAlpha == 0)
        border.stateChangeSettled(WindowID(1))
        report(border, rest)
        #expect(panel.panelAlpha == 1)
    }
}
