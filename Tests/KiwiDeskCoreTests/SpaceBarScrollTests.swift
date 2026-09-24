import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure whole-bar scroll geometry (#385, #1517): the fades at
/// the run's hidden ends, the active-item scroll follow over
/// variable-length items, the autoscroll step, and the fade-zone
/// hit test. All nonisolated, so pinned without AppKit.
@Suite("Space bar scroll geometry")
struct SpaceBarScrollTests {
    /// Both ends fading 30 pt, an entry hidden on each side.
    private let both = ShelfOverflow.Fades(
        leading: 30,
        trailing: 30,
        before: 1,
        after: 1
    )

    @Test("A run that fits fades nowhere")
    func fitsFadesNowhere() {
        #expect(
            ShelfOverflow.fades(
                lengths: [50, 50],
                gap: 6,
                total: 106,
                offset: 0,
                viewport: 200,
                depth: 40
            ) == .none
        )
    }

    /// Only the side that hides an entry fades, and it counts
    /// what it hides.
    @Test("An overflowing run fades only its hidden side")
    func overflowFadesItsHiddenSide() {
        let lengths: [CGFloat] = Array(repeating: 100, count: 5)
        let start = ShelfOverflow.fades(
            lengths: lengths,
            gap: 0,
            total: 500,
            offset: 0,
            viewport: 300,
            depth: 40
        )
        #expect(start.leading == 0 && start.before == 0)
        #expect(start.trailing > 0 && start.after == 2)
        // A sliver short of the end hides no whole entry: no fade.
        let sliver = ShelfOverflow.fades(
            lengths: lengths,
            gap: 0,
            total: 500,
            offset: 199,
            viewport: 300,
            depth: 40
        )
        #expect(sliver.trailing == 0 && sliver.after == 0)
    }

    @Test("The clear view is the viewport less its fades")
    func clearView() {
        let frame = CGRect(x: 10, y: 0, width: 200, height: 32)
        #expect(
            both.clear(of: frame, horizontal: true)
                == CGRect(x: 40, y: 0, width: 140, height: 32)
        )
    }

    @Test("A fitting run needs no scroll offset")
    func offsetFits() {
        let offset = SpaceBarOverlay.scrollOffset(
            current: 40,
            lengths: [30, 30],
            gap: 0,
            frontExtent: 0,
            activeIndex: 1,
            viewport: 100,
            margin: 0
        )
        #expect(offset == 0)
    }

    @Test("Following the active item scrolls it into view")
    func offsetFollowsActive() {
        // total 250 > viewport 100; active (last) span 200…250
        // must sit within the viewport → offset 150 (the max).
        let offset = SpaceBarOverlay.scrollOffset(
            current: 0,
            lengths: [50, 50, 50, 50, 50],
            gap: 0,
            frontExtent: 0,
            activeIndex: 4,
            viewport: 100,
            margin: 0
        )
        #expect(offset == 150)
    }

    @Test("Following a leading item scrolls back to it")
    func offsetFollowsLeadingActive() {
        let offset = SpaceBarOverlay.scrollOffset(
            current: 150,
            lengths: [50, 50, 50, 50, 50],
            gap: 0,
            frontExtent: 0,
            activeIndex: 0,
            viewport: 100,
            margin: 0
        )
        #expect(offset == 0)
    }

    @Test("A nil active index only clamps the current offset")
    func offsetClampsOnly() {
        let over = SpaceBarOverlay.scrollOffset(
            current: 999,
            lengths: [50, 50, 50, 50, 50],
            gap: 0,
            frontExtent: 0,
            activeIndex: nil,
            viewport: 100,
            margin: 0
        )
        #expect(over == 150)
        let under = SpaceBarOverlay.scrollOffset(
            current: -20,
            lengths: [50, 50, 50, 50, 50],
            gap: 0,
            frontExtent: 0,
            activeIndex: nil,
            viewport: 100,
            margin: 0
        )
        #expect(under == 0)
    }

    @Test("The autoscroll step is the average item length plus a gap")
    func step() {
        let step = SpaceBarOverlay.scrollStep(
            lengths: [10, 20, 30],
            gap: 4
        )
        #expect(step == 24)
    }

    @Test("A fade hit maps the ends of an overflowing strip")
    func fadeHitHorizontal() {
        let strip = CGRect(x: 0, y: 0, width: 200, height: 32)
        #expect(
            SpaceBarOverlay.fadeHit(
                at: CGPoint(x: 10, y: 16),
                strip: strip,
                fades: both,
                trailingAxis: 200,
                horizontal: true
            ) == .back
        )
        #expect(
            SpaceBarOverlay.fadeHit(
                at: CGPoint(x: 195, y: 16),
                strip: strip,
                fades: both,
                trailingAxis: 200,
                horizontal: true
            ) == .forward
        )
        #expect(
            SpaceBarOverlay.fadeHit(
                at: CGPoint(x: 100, y: 16),
                strip: strip,
                fades: both,
                trailingAxis: 200,
                horizontal: true
            ) == nil
        )
    }

    @Test(
        "Forward zone tracks the pinned front band, not the rim"
    )
    func fadeHitPinnedFrontBand() {
        // The front segment holds the trailing 60pt; the Spaces
        // region (and its forward fade) ends at trailingAxis 140.
        let strip = CGRect(x: 0, y: 0, width: 200, height: 32)
        // A point in the pinned band past trailingAxis is inert.
        #expect(
            SpaceBarOverlay.fadeHit(
                at: CGPoint(x: 180, y: 16),
                strip: strip,
                fades: both,
                trailingAxis: 140,
                horizontal: true
            ) == nil
        )
        // The forward fade sits just inside trailingAxis.
        #expect(
            SpaceBarOverlay.fadeHit(
                at: CGPoint(x: 135, y: 16),
                strip: strip,
                fades: both,
                trailingAxis: 140,
                horizontal: true
            ) == .forward
        )
    }

    @Test("A fade hit is inert while nothing fades")
    func fadeHitNoOverflow() {
        let strip = CGRect(x: 0, y: 0, width: 200, height: 32)
        #expect(
            SpaceBarOverlay.fadeHit(
                at: CGPoint(x: 10, y: 16),
                strip: strip,
                fades: .none,
                trailingAxis: 200,
                horizontal: true
            ) == nil
        )
    }

    @Test("A fade hit ignores points off the strip's cross axis")
    func fadeHitOffCross() {
        let strip = CGRect(x: 0, y: 0, width: 200, height: 32)
        #expect(
            SpaceBarOverlay.fadeHit(
                at: CGPoint(x: 10, y: 40),
                strip: strip,
                fades: both,
                trailingAxis: 200,
                horizontal: true
            ) == nil
        )
    }

    @Test("A fade hit maps the ends of a vertical strip")
    func fadeHitVertical() {
        let strip = CGRect(x: 0, y: 0, width: 32, height: 200)
        #expect(
            SpaceBarOverlay.fadeHit(
                at: CGPoint(x: 16, y: 10),
                strip: strip,
                fades: both,
                trailingAxis: 200,
                horizontal: false
            ) == .back
        )
        #expect(
            SpaceBarOverlay.fadeHit(
                at: CGPoint(x: 16, y: 195),
                strip: strip,
                fades: both,
                trailingAxis: 200,
                horizontal: false
            ) == .forward
        )
    }
}
