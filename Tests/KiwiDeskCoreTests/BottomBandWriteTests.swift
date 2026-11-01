import ApplicationServices
import CoreGraphics
import Foundation
import Testing
import os

@testable import KiwiDeskCore

/// A height shrink near a screen's bottom edge is written from
/// clear of that edge (#2894). The numbers are the device trace's:
/// a 1728 × 1117 screen, the lower stack slot ending 16 pt above
/// its bottom, a spring's last frame shrinking 499 → 494.5.
@Suite("A shrink near the bottom edge is written from clear of it (#2894)")
@MainActor
struct BottomBandWriteTests {
    private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let slot = CGRect(x: 16, y: 606.5, width: 840, height: 494.5)
    private let start = CGRect(x: 16, y: 602, width: 847, height: 499)

    /// An app answering as macOS did on the device: a size write
    /// is refused while the window's bottom AND the asked bottom
    /// both lie within 19 pt of the screen's bottom.
    private final class RefusingApp: Sendable {
        let frame: OSAllocatedUnfairLock<CGRect>
        let calls = OSAllocatedUnfairLock<[String]>(initialState: [])
        let screenBottom: CGFloat

        init(_ frame: CGRect, screenBottom: CGFloat) {
            self.frame = OSAllocatedUnfairLock(initialState: frame)
            self.screenBottom = screenBottom
        }

        func setSize(_ size: CGSize) {
            frame.withLock { now in
                let asked = now.minY + size.height
                let refused =
                    now.maxY > screenBottom - 19
                    && asked > screenBottom - 25
                    && size.height < now.height
                if !refused { now.size = size }
            }
        }

        func note(_ call: String) { calls.withLock { $0.append(call) } }

        var writer: FrameWriter {
            FrameWriter(
                setFrame: { rect, _ in
                    self.note("frame")
                    self.setSize(rect.size)
                    self.frame.withLock { $0.origin = rect.origin }
                    self.setSize(rect.size)
                },
                setPosition: { point, _ in
                    self.note("position")
                    self.frame.withLock { $0.origin = point }
                },
                writeEUI: { _, _ in },
                frame: { _ in
                    self.note("read")
                    return self.frame.withLock { $0 }
                }
            )
        }
    }

    private var element: AXUIElement {
        AXUIElementCreateApplication(getpid())
    }

    private func lift(_ target: CGRect, from current: CGRect) -> CGFloat? {
        BottomBandWrite.liftedY(
            target: target,
            current: current,
            screen: screen
        )
    }

    @Test("A frame ending near a screen's bottom names that screen")
    func screenNearTheBottom() {
        let near = { BottomBandWrite.screen(for: $0, among: [self.screen]) }
        #expect(near(slot) == screen)
        #expect(near(slot.offsetBy(dx: 0, dy: -200)) == nil)
        #expect(near(slot.offsetBy(dx: 0, dy: 100)) == nil)
        let beside = screen.offsetBy(dx: screen.width, dy: 0)
        #expect(BottomBandWrite.screen(for: slot, among: [beside]) == nil)
    }

    @Test("A shrink lifts the current frame clear of the band")
    func shrinkLifts() {
        #expect(lift(slot, from: start) == 1117 - BottomBandWrite.band - 499)
    }

    @Test("A lift never puts the window lower than its target")
    func liftStopsAtTheTarget() {
        let target = CGRect(x: 16, y: 500, width: 840, height: 300)
        let current = CGRect(x: 16, y: 701, width: 840, height: 400)
        #expect(lift(target, from: current) == 500)
    }

    @Test("A window arriving from another screen is lifted")
    func arrivalIsLifted() {
        let other = CGRect(x: -1080, y: 0, width: 1080, height: 1920)
        let current = CGRect(x: -1000, y: 300, width: 840, height: 499)
        #expect(other.contains(current))
        let above = CGRect(x: 16, y: -800, width: 840, height: 499)
        #expect(lift(slot, from: above) == 1117 - BottomBandWrite.band - 499)
        #expect(lift(slot, from: current) == 1117 - BottomBandWrite.band - 499)
    }

    @Test("Nothing refused, nothing lifted")
    func nothingRefusedIsNotLifted() {
        // A grow, an unchanged height, a bottom already clear of
        // the band, and a window too tall for any lift to clear.
        let grow = CGRect(x: 16, y: 602, width: 840, height: 400)
        let clear = start.offsetBy(dx: 0, dy: -300)
        let tall = CGRect(x: 0, y: 17, width: 1728, height: 1100)
        #expect(lift(slot, from: grow) == nil)
        #expect(lift(slot, from: slot) == nil)
        #expect(lift(slot, from: clear) == nil)
        #expect(lift(tall.insetBy(dx: 0, dy: 10), from: tall) == nil)
    }

    @Test("The refusing app keeps the old height without the lift")
    func unliftedWriteIsRefused() {
        let app = RefusingApp(start, screenBottom: screen.maxY)
        BottomBandWrite.write(
            slot,
            element,
            nearBottomOf: nil,
            writer: app.writer
        )
        #expect(app.frame.withLock { $0.height } == 499)
    }

    @Test("The lifted write lands the asked frame")
    func liftedWriteLands() {
        let app = RefusingApp(start, screenBottom: screen.maxY)
        BottomBandWrite.write(
            slot,
            element,
            nearBottomOf: screen,
            writer: app.writer
        )
        #expect(app.frame.withLock { $0 } == slot)
        #expect(
            app.calls.withLock { $0 } == ["read", "position", "frame"]
        )
    }

    /// Each applier door with a size: the animation's, the
    /// instant set's and the hold's release (#1956).
    enum Door: String, CaseIterable { case animated, instant, held }

    private func send(
        _ frame: CGRect,
        through door: Door,
        _ applier: FrameApplier,
        _ app: RefusingApp
    ) async throws {
        let id = WindowID(1)
        let before = app.calls.withLock { $0.count }
        switch door {
        case .animated:
            applier.apply(id, frame, setSize: true)
        case .instant:
            applier.applyInstant(id, frame, setSize: true)
        case .held:
            applier.holdWrites([id], until: .now() + 0.05)
            applier.applyInstant(id, frame, setSize: true)
        }
        // A generous guard, never a tight deadline (#344).
        for _ in 0..<500
        where app.calls.withLock({ $0.count }) == before {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func makeApplier(_ app: RefusingApp) -> FrameApplier {
        let applier = FrameApplier()
        let element = element
        applier.elementProvider = { _ in element }
        applier.writer = app.writer
        applier.screenFrames = { [screen] in [screen] }
        // The echo-fed height: what the window reports of itself.
        applier.trackedHeight = { _ in app.frame.withLock { $0.height } }
        return applier
    }

    @Test(
        "Every applier write path writes through the band",
        arguments: Door.allCases
    )
    func applierWritesThroughTheBand(door: Door) async throws {
        let app = RefusingApp(start, screenBottom: screen.maxY)
        try await send(slot, through: door, makeApplier(app), app)
        #expect(app.frame.withLock { $0 } == slot)
    }

    /// The app grew its own window back after a landed ask, and
    /// the layout asks the same height again: the window's answer,
    /// not the last ask, says it shrinks.
    @Test(
        "A shrink the app made necessary is lifted too",
        arguments: Door.allCases
    )
    func unaskedGrowIsLifted(door: Door) async throws {
        let app = RefusingApp(start, screenBottom: screen.maxY)
        let applier = makeApplier(app)
        try await send(slot, through: door, applier, app)
        app.frame.withLock { $0 = start }
        try await send(slot, through: door, applier, app)
        #expect(app.frame.withLock { $0 } == slot)
    }

    @Test(
        "A write no shorter than the tracked height reads nothing",
        arguments: Door.allCases
    )
    func sameHeightReadsNothing(door: Door) async throws {
        let app = RefusingApp(slot, screenBottom: screen.maxY)
        let applier = makeApplier(app)
        // The first sized write has no sent height to compare.
        try await send(slot, through: door, applier, app)
        app.calls.withLock { $0.removeAll() }
        try await send(slot, through: door, applier, app)
        #expect(app.calls.withLock { $0 } == ["frame"])
    }

    /// A spring's shrink-back after an overshoot: the echo still
    /// reports a height from before the peak, the frame sent last
    /// was the peak, and the window is at the peak.
    @Test(
        "A shrink-back the echo has not reached is lifted",
        arguments: Door.allCases
    )
    func overshootShrinkBackIsLifted(door: Door) async throws {
        let app = RefusingApp(start, screenBottom: screen.maxY)
        let applier = makeApplier(app)
        applier.trackedHeight = { _ in 480 }
        try await send(start, through: door, applier, app)
        try await send(slot, through: door, applier, app)
        #expect(app.frame.withLock { $0 } == slot)
    }

    /// A sized write merged into a held position-only one keeps
    /// its band (#1956's merge).
    @Test("A held merge carries the band")
    func heldMergeCarriesTheBand() async throws {
        let app = RefusingApp(start, screenBottom: screen.maxY)
        let applier = makeApplier(app)
        let id = WindowID(1)
        applier.holdWrites([id], until: .now() + 0.05)
        applier.applyInstant(id, slot, setSize: false)
        applier.applyInstant(id, slot, setSize: true)
        // A generous guard, never a tight deadline (#344).
        for _ in 0..<500 where app.calls.withLock({ $0.isEmpty }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(app.frame.withLock { $0 } == slot)
    }

    @Test("A position-only frame merged into a sized one keeps its band")
    func pendingMergeKeepsTheBand() {
        let pending = PendingFrames()
        let id = WindowID(1)
        _ = pending.put(
            id,
            .init(element: element, frame: slot, setSize: true, band: screen)
        )
        _ = pending.put(
            id,
            .init(element: element, frame: slot, setSize: false)
        )
        let entry = pending.take(id)
        #expect(entry?.setSize == true)
        #expect(entry?.band == screen)
    }

    @Test("A taller sized frame merged into a waiting shrink keeps its band")
    func pendingSizedMergeKeepsTheBand() {
        let pending = PendingFrames()
        let id = WindowID(1)
        let taller = slot.insetBy(dx: 0, dy: -1)
        _ = pending.put(
            id,
            .init(element: element, frame: slot, setSize: true, band: screen)
        )
        _ = pending.put(
            id,
            .init(element: element, frame: taller, setSize: true)
        )
        #expect(pending.take(id)?.band == screen)
    }

    @Test("A write far from any bottom edge reads nothing")
    func farWriteReadsNothing() async throws {
        let high = slot.offsetBy(dx: 0, dy: -300)
        let app = RefusingApp(
            start.offsetBy(dx: 0, dy: -300),
            screenBottom: screen.maxY
        )
        try await send(high, through: .instant, makeApplier(app), app)
        #expect(app.calls.withLock { $0 } == ["frame"])
    }

    @Test("The engine hands the applier its screen frames")
    func engineWiresTheScreens() {
        let engine = TilingEngine()
        engine.allScreenFrames = { [screen] in [screen] }
        #expect(engine.applier.screenFrames() == [screen])
    }
}
