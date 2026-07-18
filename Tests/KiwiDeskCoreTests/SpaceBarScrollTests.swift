import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure whole-bar scroll geometry (#385): the arrow-zone
/// viewport inset, the active-item scroll follow over
/// variable-length items, the click/autoscroll step, and the
/// arrow-zone hit test. All nonisolated, so pinned without AppKit.
@Suite("Space bar scroll geometry")
struct SpaceBarScrollTests {
    private let zone = BarArrowView.zone  // 24

    @Test("A run that fits reserves no arrow zone")
    func viewportFits() {
        let (inset, viewport) = SpaceBarOverlay.scrollViewport(
            axis: 200,
            total: 150,
            gap: 6
        )
        #expect(inset == 0)
        #expect(viewport == 200)
    }

    @Test("An overflowing run insets an arrow zone plus a gap")
    func viewportOverflows() {
        let (inset, viewport) = SpaceBarOverlay.scrollViewport(
            axis: 200,
            total: 300,
            gap: 6
        )
        #expect(inset == zone + 6)
        #expect(viewport == 200 - (zone + 6) * 2)
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

    @Test("The scroll step is the average item length plus a gap")
    func step() {
        let step = SpaceBarOverlay.scrollStep(
            lengths: [10, 20, 30],
            gap: 4
        )
        #expect(step == 24)
    }

    @Test("Arrow hit maps the ends of an overflowing strip")
    func arrowHitHorizontal() {
        let strip = CGRect(x: 0, y: 0, width: 200, height: 32)
        #expect(
            SpaceBarOverlay.arrowHit(
                at: CGPoint(x: 10, y: 16),
                strip: strip,
                inset: zone + 6,
                horizontal: true
            ) == .back
        )
        #expect(
            SpaceBarOverlay.arrowHit(
                at: CGPoint(x: 195, y: 16),
                strip: strip,
                inset: zone + 6,
                horizontal: true
            ) == .forward
        )
        #expect(
            SpaceBarOverlay.arrowHit(
                at: CGPoint(x: 100, y: 16),
                strip: strip,
                inset: zone + 6,
                horizontal: true
            ) == nil
        )
    }

    @Test("Arrow hit is inert while the run fits (inset 0)")
    func arrowHitNoOverflow() {
        let strip = CGRect(x: 0, y: 0, width: 200, height: 32)
        #expect(
            SpaceBarOverlay.arrowHit(
                at: CGPoint(x: 10, y: 16),
                strip: strip,
                inset: 0,
                horizontal: true
            ) == nil
        )
    }

    @Test("Arrow hit ignores points off the strip's cross axis")
    func arrowHitOffCross() {
        let strip = CGRect(x: 0, y: 0, width: 200, height: 32)
        #expect(
            SpaceBarOverlay.arrowHit(
                at: CGPoint(x: 10, y: 40),
                strip: strip,
                inset: zone + 6,
                horizontal: true
            ) == nil
        )
    }

    @Test("Arrow hit maps the ends of a vertical strip")
    func arrowHitVertical() {
        let strip = CGRect(x: 0, y: 0, width: 32, height: 200)
        #expect(
            SpaceBarOverlay.arrowHit(
                at: CGPoint(x: 16, y: 10),
                strip: strip,
                inset: zone + 6,
                horizontal: false
            ) == .back
        )
        #expect(
            SpaceBarOverlay.arrowHit(
                at: CGPoint(x: 16, y: 195),
                strip: strip,
                inset: zone + 6,
                horizontal: false
            ) == .forward
        )
    }
}
