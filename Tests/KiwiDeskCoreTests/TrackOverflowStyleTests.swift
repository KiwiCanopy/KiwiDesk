import CoreGraphics
import Testing

@testable import KiwiDeskCore

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private func makeContext(
    bounds: CGRect,
    breaks: Set<WindowID> = [],
    tune: (inout LayoutContext) -> Void = { _ in }
) -> LayoutContext {
    var context = LayoutContext(
        bounds: bounds,
        gaps: .uniform(10),
        trackBreaks: breaks,
        trackWeights: [:]
    )
    tune(&context)
    return context
}

/// The overflow track (#192): too many tracks to tile side by
/// side fold their surplus into ONE far-edge overflow track,
/// which alone honors `overflow_style` (default `cascade_all`).
/// Every *normal* track's internal overflow is always
/// `cascade_overflow`.
@Suite("Track overflow track (#192)")
struct TrackOverflowStyleTests {
    let layout = TrackLayout()

    @Test("fitCap: min-size tracks that fit, gap-aware")
    func fitCapFormula() {
        // 3 tracks · 300 + 2 gaps · 20 = 940 fits exactly; a 4th
        // needs 1260.
        #expect(
            TrackLayout.fitCap(crossSpan: 940, minSize: 300, gap: 20)
                == 3
        )
        #expect(
            TrackLayout.fitCap(crossSpan: 620, minSize: 300, gap: 20)
                == 2
        )
        // Exact single-track fit, and a span too small for one.
        #expect(
            TrackLayout.fitCap(crossSpan: 300, minSize: 300, gap: 20)
                == 1
        )
        #expect(
            TrackLayout.fitCap(crossSpan: 200, minSize: 300, gap: 20)
                == 0
        )
        // No min size → unlimited (matches maxColumnTotal).
        #expect(
            TrackLayout.fitCap(crossSpan: 500, minSize: 0, gap: 20)
                == .max
        )
    }

    @Test("The overflow track honors overflow_style")
    func overflowTrackHonorsStyle() {
        // 8 single-window tracks, 700 pt / 300 min (gap 10) → 2
        // columns fit, so w1..w7 merge into the far-edge overflow
        // track. Its internal pile follows overflow_style.
        let w = ids(8)
        func overflowHeights(
            _ style: StackParams.OverflowStyle
        ) -> Set<CGFloat> {
            let frames = layout.calculateGeometry(
                for: w,
                in: makeContext(
                    bounds: CGRect(x: 0, y: 0, width: 700, height: 900),
                    breaks: Set(w)
                ) {
                    $0.minWindowSize = 300
                    $0.track.overflowStyle = style
                }
            )
            let overflowX = w.map { frames[$0]!.minX }.max()!
            return Set(
                w.filter { frames[$0]!.minX == overflowX }
                    .map { frames[$0]!.height }
            )
        }
        // cascade_all: every overflow window keeps the full region
        // height (all equal, piled from the top).
        #expect(overflowHeights(.cascadeAll).count == 1)
        // cascade_overflow: a tiled prefix makes the heights vary.
        #expect(overflowHeights(.cascadeOverflow).count > 1)
    }

    @Test("A normal track is always cascade_overflow")
    func normalTrackAlwaysCascadeOverflow() {
        // Two tracks that both fit (no merge, so no overflow
        // track). Track 0 holds six windows and overflows
        // internally — it must tile-then-pile even with the
        // global style set to cascade_all.
        let w = ids(7)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(x: 0, y: 0, width: 700, height: 900),
                breaks: [w[0], w[6]]
            ) {
                $0.minWindowSize = 300
                $0.track.overflowStyle = .cascadeAll
            }
        )
        // Track 0 = w0..w5 (a normal track); its heights vary =
        // a tiled prefix, i.e. cascade_overflow, not an all-pile.
        let track0 = Array(w[0..<6])
        #expect(Set(track0.map { frames[$0]!.height }).count > 1)
    }

    @Test("A fixed track cap forms the overflow track too")
    func fixedCapOverflowTrack() {
        // auto off, count 2 on a wide screen: the fixed cap (not
        // geometry) folds w1..w4 into the overflow track, which
        // still renders per overflow_style — one unified path.
        let w = ids(5)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(x: 0, y: 0, width: 3000, height: 900),
                breaks: Set(w)
            ) {
                $0.minWindowSize = 300
                $0.track.autoTracks = false
                $0.track.count = 2
                $0.track.overflowStyle = .cascadeAll
            }
        )
        let xs = w.map { frames[$0]!.minX }
        #expect(Set(xs).count == 2)
        let overflowX = xs.max()!
        let inOverflow = w.filter { frames[$0]!.minX == overflowX }
        #expect(Set(inOverflow) == Set(w[1...]))
        // cascade_all piles them: stepped y at a shared x.
        let oy = inOverflow.map { frames[$0]!.minY }.sorted()
        #expect(abs((oy[1] - oy[0]) - 40) < 0.001)
    }
}
