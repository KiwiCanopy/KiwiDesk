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
        border.commandedFrame = { [rest] _ in rest }
        return border
    }

    /// A shown ring, then held for a state change.
    private func heldRing(
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
        let panel = try #require(ring.backend as? AppKitBorderOverlay)
        #expect(panel.panelAlpha == 1)
        border.holdStateChange(of: WindowID(1))
        return panel
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

    /// The hold has one door: every state change reaches it
    /// through `holdRingForStateChange`.
    @Test("the hold is armed from the one door")
    func oneDoor() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/KiwiDeskCore")
        var callers: [String] = []
        let files = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains("borders.holdStateChange(") {
                callers.append(url.lastPathComponent)
            }
        }
        #expect(callers == ["KiwiCore+StateChange.swift"])
    }
}
