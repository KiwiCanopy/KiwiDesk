import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pure math of a float whose app holds its ratio (#2973). The
/// answers are the sizes mpv and QuickTime Player gave on 2026-11-04.
@Suite("Float resize, aspect (#2973)")
struct FloatResizeAspectTests {
    private let frame = CGRect(x: 400, y: 200, width: 800, height: 450)
    private let ratio: CGFloat = 800.0 / 450.0
    private let floor = CGSize(width: 200, height: 100)
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    private func answer(
        _ width: CGFloat,
        _ height: CGFloat,
        horizontal: Bool = true
    ) -> FloatResize.AspectAnswer {
        FloatResize.aspectAnswer(
            base: frame.size,
            answered: CGSize(width: width, height: height),
            horizontal: horizontal
        )
    }

    @Test("Both axes moving at the ratio reads as fitted")
    func shrinkIsFitted() {
        #expect(answer(679, 382) == .fitted)
        #expect(answer(586, 330, horizontal: false) == .fitted)
    }

    @Test("Staying put reads as unchanged, within an app's rounding")
    func growIsUnchanged() {
        #expect(answer(800, 450) == .unchanged)
        #expect(answer(799, 450) == .unchanged)
    }

    @Test("Only the pressed axis moving reads as a free window")
    func freeWindow() {
        #expect(answer(920, 450) == .complied)
        #expect(answer(800, 570, horizontal: false) == .complied)
    }

    @Test("A short answer on the pressed axis alone proves no lock")
    func snappedIsNoFit() {
        // A cell-grid app stopping short: ratio drift 0.011, inside the
        // tolerance, and still not a lock, since the height never moved.
        #expect(answer(795, 450) == .complied)
    }

    @Test("A broken ratio, or the other axis alone, is no fit")
    func brokenRatio() {
        #expect(answer(860, 400) == .other)
        #expect(answer(800, 400) == .other)
    }

    @Test("An ask is readable once a lock would move the other axis")
    func askIsReadable() {
        func readable(_ width: CGFloat, _ height: CGFloat, _ h: Bool) -> Bool {
            FloatResize.aspectAskIsReadable(
                base: frame.size,
                asked: CGSize(width: width, height: height),
                horizontal: h
            )
        }
        #expect(!readable(796, 450, true))
        #expect(readable(790, 450, true))
        #expect(readable(800, 447, false))
        #expect(!readable(800, 449, false))
    }

    @Test("Either axis scales both, about the window's centre")
    func scalesBoth() {
        let wide = FloatResize.scaled(
            frame,
            horizontal: true,
            delta: 80,
            ratio: ratio,
            minSize: floor,
            bounds: screen
        )
        #expect(wide.frame.size == CGSize(width: 880, height: 495))
        #expect(wide.frame.midX == frame.midX)
        #expect(abs(wide.frame.midY - frame.midY) <= 0.5)
        #expect(wide.refusal == nil)
        let tall = FloatResize.scaled(
            frame,
            horizontal: false,
            delta: 45,
            ratio: ratio,
            minSize: floor,
            bounds: screen
        )
        #expect(tall.frame.size == CGSize(width: 880, height: 495))
    }

    @Test("The first boundary stops both axes and refuses the rest")
    func boundaryStopsBoth() {
        let short = CGRect(x: 0, y: 0, width: 1600, height: 500)
        let outcome = FloatResize.scaled(
            CGRect(x: 400, y: 20, width: 800, height: 450),
            horizontal: true,
            delta: 400,
            ratio: ratio,
            minSize: floor,
            bounds: short
        )
        #expect(abs(outcome.frame.height - 500) < 0.5)
        #expect(
            abs(outcome.frame.width / outcome.frame.height - ratio)
                <= FloatResize.ratioTolerance
        )
        #expect(outcome.refusal == .truncated)
    }

    @Test("A window at its boundary is left exactly as it stands")
    func blocked() {
        // 470 high against a held 1.778 would read 450: a refused press
        // must not re-derive the height.
        let tall = CGRect(x: 400, y: 0, width: 800, height: 470)
        let outcome = FloatResize.scaled(
            tall,
            horizontal: true,
            delta: 50,
            ratio: ratio,
            minSize: floor,
            bounds: CGRect(x: 400, y: 0, width: 800, height: 1000)
        )
        #expect(outcome.frame == tall)
        #expect(outcome.refusal == .blocked)
    }

    @Test("A glide frame's small delta has room, and accumulates")
    func smallDeltaIsNotBlocked() {
        // `step * 6 * dt` at 120 Hz is under 1 pt: a judge reading the
        // delta instead of the room would call this a wall.
        var current = frame
        for _ in 0..<10 {
            let outcome = FloatResize.scaled(
                current,
                horizontal: true,
                delta: 0.4,
                ratio: ratio,
                minSize: floor,
                bounds: screen
            )
            #expect(outcome.refusal == nil)
            current = outcome.frame
        }
        #expect(abs(current.width - 804) < 0.01)
    }

    @Test("A shrink stops both axes at the higher floor")
    func floorStopsBoth() {
        let outcome = FloatResize.scaled(
            frame,
            horizontal: true,
            delta: -700,
            ratio: ratio,
            minSize: CGSize(width: 200, height: 225),
            bounds: screen
        )
        #expect(outcome.frame.size == CGSize(width: 400, height: 225))
    }

    @Test("Rounding keeps the held ratio, and a new video replaces it")
    func heldRatio() {
        #expect(FloatResize.heldRatio(1.778, measured: 1.759) == 1.778)
        #expect(FloatResize.heldRatio(1.778, measured: 2.39) == 2.39)
    }
}
