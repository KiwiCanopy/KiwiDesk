import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Pure geometry of the float nudge (`FloatNudge.target`). AX
/// coordinates throughout: origin top-left, y grows downward, so
/// the visible frame's bottom edge is `maxY`.
@Suite("Float nudge geometry")
struct FloatNudgeTests {
    /// A 1000×1000 visible frame; center at (500, 500).
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    private func center(_ rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    @Test("Far window shoves a fixed 24 pt toward center")
    func fixedMagnitude() {
        // Centered at (500, 800): 300 pt straight below center.
        let frame = CGRect(x: 450, y: 750, width: 100, height: 100)
        let result = FloatNudge.target(frame: frame, visible: visible)
        // Moves exactly maxDistance, straight up toward center.
        #expect(
            abs(distance(center(result), center(frame)) - 24) < 0.001
        )
        #expect(abs(result.midX - 500) < 0.001)
        #expect(abs(result.midY - 776) < 0.001)
    }

    @Test("Fixed magnitude ignores window size (no teleport)")
    func magnitudeIndependentOfSize() {
        // A large window off-center by 200 pt (and still fully on
        // screen) must shove the same 24 pt as a small one — a
        // size-proportional nudge would teleport it.
        let frame = CGRect(x: 50, y: 400, width: 900, height: 600)
        let result = FloatNudge.target(frame: frame, visible: visible)
        #expect(
            abs(distance(center(result), center(frame)) - 24) < 0.001
        )
    }

    @Test("Near-center window tapers below the cap")
    func nearCenterTapers() {
        // Center only 10 pt from the visible center → shove 10 pt
        // (min(24, 10)), landing exactly on center.
        let frame = CGRect(x: 450, y: 460, width: 100, height: 100)
        let result = FloatNudge.target(frame: frame, visible: visible)
        let moved = distance(center(result), center(frame))
        #expect(moved < 24)
        #expect(abs(moved - 10) < 0.001)
        #expect(abs(result.midX - 500) < 0.001)
        #expect(abs(result.midY - 500) < 0.001)
    }

    @Test("Dead-center window shoves straight down")
    func deadCenterGoesDown() {
        // Exactly on center: direction undefined → straight down
        // (increasing y in AX) by the cap.
        let frame = CGRect(x: 450, y: 450, width: 100, height: 100)
        let result = FloatNudge.target(frame: frame, visible: visible)
        #expect(abs(result.midX - 500) < 0.001)
        #expect(abs(result.midY - 524) < 0.001)
    }

    @Test("Result is always confined on screen")
    func clampsOnScreen() {
        // A window hanging off the top edge, nudged toward center:
        // the result must sit fully inside the visible frame.
        let frame = CGRect(x: 450, y: -38, width: 100, height: 100)
        let result = FloatNudge.target(frame: frame, visible: visible)
        #expect(result.minX >= visible.minX)
        #expect(result.minY >= visible.minY)
        #expect(result.maxX <= visible.maxX)
        #expect(result.maxY <= visible.maxY)
    }
}
