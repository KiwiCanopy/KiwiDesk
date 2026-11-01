import ApplicationServices
import CoreGraphics
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

        var writer: FrameWriter {
            FrameWriter(
                setFrame: { rect, _ in
                    self.calls.withLock { $0.append("frame") }
                    self.setSize(rect.size)
                    self.frame.withLock { $0.origin = rect.origin }
                    self.setSize(rect.size)
                },
                setPosition: { point, _ in
                    self.calls.withLock { $0.append("position") }
                    self.frame.withLock { $0.origin = point }
                },
                writeEUI: { _, _ in },
                size: { _ in self.frame.withLock { $0.size } }
            )
        }
    }

    private var element: AXUIElement {
        AXUIElementCreateApplication(getpid())
    }

    @Test("A frame ending near a screen's bottom names that screen")
    func screenNearTheBottom() {
        #expect(BottomBandWrite.screen(for: slot, among: [screen]) == screen)
        let high = slot.offsetBy(dx: 0, dy: -200)
        #expect(BottomBandWrite.screen(for: high, among: [screen]) == nil)
        let other = CGRect(x: -1080, y: 0, width: 1080, height: 1920)
        #expect(BottomBandWrite.screen(for: slot, among: [other]) == nil)
    }

    @Test("A shrink lifts the current height clear of the band")
    func shrinkLifts() {
        let current = CGSize(width: 840, height: 499)
        let y = BottomBandWrite.liftedY(
            target: slot,
            current: current,
            screen: screen
        )
        #expect(y == 1117 - BottomBandWrite.band - 499)
    }

    @Test("A grow or an unchanged height is not lifted")
    func growIsNotLifted() {
        for height in [494.5, 400.0] {
            let current = CGSize(width: 840, height: height)
            let y = BottomBandWrite.liftedY(
                target: slot,
                current: current,
                screen: screen
            )
            #expect(y == nil)
        }
    }

    @Test("A lift stops at the screen's top")
    func liftStopsAtTheTop() {
        let current = CGSize(width: 1728, height: 1117)
        let y = BottomBandWrite.liftedY(
            target: slot,
            current: current,
            screen: screen
        )
        #expect(y == screen.minY)
    }

    @Test("The refusing app keeps the old height without the lift")
    func unliftedWriteIsRefused() {
        let start = CGRect(x: 16, y: 602, width: 847, height: 499)
        let app = RefusingApp(start, screenBottom: screen.maxY)
        BottomBandWrite.write(
            slot,
            element,
            screens: [],
            writer: app.writer
        )
        #expect(app.frame.withLock { $0.height } == 499)
    }

    @Test("The lifted write lands the asked frame")
    func liftedWriteLands() {
        let start = CGRect(x: 16, y: 602, width: 847, height: 499)
        let app = RefusingApp(start, screenBottom: screen.maxY)
        BottomBandWrite.write(
            slot,
            element,
            screens: [screen],
            writer: app.writer
        )
        #expect(app.frame.withLock { $0 } == slot)
        #expect(app.calls.withLock { $0 } == ["position", "frame"])
    }

    @Test("A write far from the bottom is the plain frame write")
    func farWriteIsPlain() {
        let high = slot.offsetBy(dx: 0, dy: -300)
        let start = CGRect(x: 16, y: 302, width: 847, height: 499)
        let app = RefusingApp(start, screenBottom: screen.maxY)
        BottomBandWrite.write(
            high,
            element,
            screens: [screen],
            writer: app.writer
        )
        #expect(app.calls.withLock { $0 } == ["frame"])
        #expect(app.frame.withLock { $0 } == high)
    }

    @Test(
        "Both applier paths write through the band",
        arguments: [true, false]
    )
    func applierWritesThroughTheBand(instant: Bool) async {
        let start = CGRect(x: 16, y: 602, width: 847, height: 499)
        let app = RefusingApp(start, screenBottom: screen.maxY)
        let applier = FrameApplier()
        let element = element
        applier.elementProvider = { _ in element }
        applier.writer = app.writer
        applier.screenFrames = { [screen] in [screen] }
        if instant {
            applier.applyInstant(WindowID(1), slot, setSize: true)
        } else {
            applier.apply(WindowID(1), slot, setSize: true)
        }
        await withCheckedContinuation { done in
            DispatchQueue.main.async { done.resume() }
        }
        #expect(app.frame.withLock { $0 } == slot)
    }

    @Test("The engine hands the applier its screen frames")
    func engineWiresTheScreens() {
        let engine = TilingEngine()
        engine.allScreenFrames = { [screen] in [screen] }
        #expect(engine.applier.screenFrames() == [screen])
    }
}
