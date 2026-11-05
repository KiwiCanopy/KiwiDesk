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

    /// mpv fits itself inside a ratio's height and shrinks (#3018).
    /// Both axes stop together, so a drifted window's spare height
    /// stands too (340x200 here has 8 pt above its floor).
    @Test("A window at its floor is left exactly as it stands")
    func atFloor() {
        let sizes = [
            CGSize(width: 328, height: 192),
            CGSize(width: 340, height: 200),
        ]
        for size in sizes {
            let drifted = CGRect(origin: CGPoint(x: 400, y: 0), size: size)
            for horizontal in [true, false] {
                let outcome = FloatResize.scaled(
                    drifted,
                    horizontal: horizontal,
                    delta: -50,
                    ratio: ratio,
                    minSize: CGSize(width: 300, height: 192),
                    bounds: nil
                )
                #expect(outcome.frame == drifted)
            }
        }
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

    @Test("The other axis alone never reads as a fit, whatever its ratio")
    func otherAxisAlone() {
        // Drift 0.012: inside the tolerance, so only the pressed axis tells.
        #expect(answer(800, 447) == .other)
    }

    @Test("A y ask is carried at the ratio, and a zero base reads nothing")
    func readableEdges() {
        // 2 pt of height carries 3.56 of width, past the tolerance.
        #expect(
            FloatResize.aspectAskIsReadable(
                base: frame.size,
                asked: CGSize(width: 800, height: 448),
                horizontal: false
            )
        )
        #expect(
            !FloatResize.aspectAskIsReadable(
                base: CGSize(width: 0, height: 450),
                asked: CGSize(width: 50, height: 450),
                horizontal: true
            )
        )
    }

    @Test("A move on y alone is another origin")
    func sameOriginReadsBothAxes() {
        #expect(!FloatResize.sameOrigin(frame, frame.offsetBy(dx: 0, dy: 40)))
        #expect(!FloatResize.sameOrigin(frame, frame.offsetBy(dx: 40, dy: 0)))
        #expect(FloatResize.sameOrigin(frame, frame.offsetBy(dx: 2, dy: 2)))
    }

    @Test("A grow never shrinks, and a shrink never grows")
    func directionHolds() {
        // Inside the held band: 441 high at the ratio would be 784 wide.
        let grow = FloatResize.scaled(
            CGRect(x: 400, y: 200, width: 800, height: 440),
            horizontal: false,
            delta: 1,
            ratio: ratio,
            minSize: floor,
            bounds: screen
        )
        #expect(grow.frame.width == 800)
        // A height floor above the window's own never lifts it.
        let shrink = FloatResize.scaled(
            CGRect(x: 400, y: 200, width: 700, height: 450),
            horizontal: true,
            delta: -50,
            ratio: ratio,
            minSize: CGSize(width: 100, height: 500),
            bounds: screen
        )
        #expect(shrink.frame.width == 700)
    }

    @Test("A width floor stops both axes when it is the higher")
    func widthFloorStopsBoth() {
        let outcome = FloatResize.scaled(
            frame,
            horizontal: true,
            delta: -700,
            ratio: ratio,
            minSize: CGSize(width: 600, height: 100),
            bounds: screen
        )
        #expect(outcome.frame.width == 600)
        #expect(abs(outcome.frame.height - 600 / ratio) < 0.01)
    }

    @Test("Rounding keeps the held ratio, and a new video replaces it")
    func heldRatio() {
        #expect(FloatResize.heldRatio(1.778, measured: 1.759) == 1.778)
        #expect(FloatResize.heldRatio(1.778, measured: 2.39) == 2.39)
    }
}
