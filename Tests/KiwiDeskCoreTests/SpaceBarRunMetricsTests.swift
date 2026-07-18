import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure Space Bar run geometry (#372): item frames and the
/// trailing front-segment origin per alignment, edge, and front
/// extent. Shared by `render()` and the drag-drop hit test, so it
/// is pinned independently.
@Suite("Space bar run metrics")
struct SpaceBarRunMetricsTests {
    private let horizontalStrip = CGRect(
        x: 0,
        y: 0,
        width: 200,
        height: 32
    )
    private let lengths: [CGFloat] = [20, 20, 20]

    @Test("Start alignment packs the run from the pad")
    func startAlignment() {
        let m = SpaceBarOverlay.runMetrics(
            lengths: lengths,
            gap: 4,
            frontExtent: 0,
            strip: horizontalStrip,
            viewport: 200,
            horizontal: true,
            alignment: .start,
            pad: 4,
            scrollOffset: 0
        )
        #expect(m.itemFrames.map(\.minX) == [4, 28, 52])
        #expect(m.itemFrames.allSatisfy { $0.width == 20 })
        #expect(m.itemFrames.allSatisfy { $0.height == 32 })
        // Trailing cursor is one gap past the last item.
        #expect(m.frontStart == 76)
    }

    @Test("Center alignment splits the slack both sides")
    func centerAlignment() {
        // total = 60 + 2*4 gaps = 68; slack = (200 - 68)/2 = 66.
        let m = SpaceBarOverlay.runMetrics(
            lengths: lengths,
            gap: 4,
            frontExtent: 0,
            strip: horizontalStrip,
            viewport: 200,
            horizontal: true,
            alignment: .center,
            pad: 4,
            scrollOffset: 0
        )
        #expect(m.itemFrames.map(\.minX) == [66, 90, 114])
    }

    @Test("End alignment right-justifies, front extent included")
    func endAlignmentWithFront() {
        // total = 68 + front 12 = 80; start = 200 - 80 - 4 = 116.
        let m = SpaceBarOverlay.runMetrics(
            lengths: lengths,
            gap: 4,
            frontExtent: 12,
            strip: horizontalStrip,
            viewport: 200,
            horizontal: true,
            alignment: .end,
            pad: 4,
            scrollOffset: 0
        )
        #expect(m.itemFrames.first?.minX == 116)
        // The cursor advances a gap after every item (including
        // the last), so the front segment starts one gap past the
        // last item — a faithfully-preserved pre-extraction quirk:
        // start 116 + 3 items (60) + 3 gaps (12) = 188.
        #expect(m.frontStart == 188)
        #expect(m.frontStart + 12 == 200)
    }

    @Test("Vertical strip lays the run down the y axis")
    func verticalAxis() {
        let strip = CGRect(x: 0, y: 0, width: 32, height: 200)
        let m = SpaceBarOverlay.runMetrics(
            lengths: lengths,
            gap: 4,
            frontExtent: 0,
            strip: strip,
            viewport: 200,
            horizontal: false,
            alignment: .start,
            pad: 4,
            scrollOffset: 0
        )
        #expect(m.itemFrames.map(\.minY) == [4, 28, 52])
        #expect(m.itemFrames.allSatisfy { $0.minX == 0 })
        #expect(m.itemFrames.allSatisfy { $0.width == 32 })
        #expect(m.itemFrames.map(\.height) == [20, 20, 20])
    }

    @Test("An overflowing run starts at the scroll offset")
    func overflowStartsAtOffset() {
        // total 404 > viewport 180: alignment collapses, the run
        // begins at -scrollOffset regardless of alignment.
        let m = SpaceBarOverlay.runMetrics(
            lengths: [200, 200],
            gap: 4,
            frontExtent: 0,
            strip: horizontalStrip,
            viewport: 180,
            horizontal: true,
            alignment: .center,
            pad: 4,
            scrollOffset: 50
        )
        #expect(m.itemFrames.map(\.minX) == [-50, 154])
    }
}
