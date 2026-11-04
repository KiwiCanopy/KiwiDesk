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
        _ asked: (CGFloat, CGFloat),
        _ answered: (CGFloat, CGFloat)
    ) -> FloatResize.AspectAnswer {
        FloatResize.aspectAnswer(
            base: frame.size,
            asked: CGSize(width: asked.0, height: asked.1),
            answered: CGSize(width: answered.0, height: answered.1)
        )
    }

    @Test("A shrink a lock fits inside its box reads as fitted")
    func shrinkIsFitted() {
        #expect(answer((680, 450), (679, 382)) == .fitted)
        #expect(answer((800, 330), (586, 330)) == .fitted)
    }

    @Test("A grow a lock refuses reads as unchanged")
    func growIsUnchanged() {
        #expect(answer((920, 450), (799, 450)) == .unchanged)
        #expect(answer((800, 570), (800, 450)) == .unchanged)
    }

    @Test("A free window complies, and a broken ratio is no fit")
    func freeWindow() {
        #expect(answer((920, 450), (920, 450)) == .complied)
        #expect(answer((920, 600), (860, 400)) == .other)
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
        #expect(outcome.frame.height == 500)
        #expect(
            abs(outcome.frame.width / outcome.frame.height - ratio)
                <= FloatResize.ratioTolerance
        )
        #expect(outcome.refusal == .truncated)
    }

    @Test("A window at its boundary takes nothing")
    func blocked() {
        let outcome = FloatResize.scaled(
            frame,
            horizontal: true,
            delta: 50,
            ratio: ratio,
            minSize: floor,
            bounds: CGRect(x: 400, y: 0, width: 800, height: 1000)
        )
        #expect(outcome.frame.size == frame.size)
        #expect(outcome.refusal == .blocked)
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
