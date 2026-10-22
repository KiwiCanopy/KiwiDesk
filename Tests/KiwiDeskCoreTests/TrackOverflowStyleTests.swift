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
/// which scrolls its windows like every other track (#2235): as
/// many as fit are shown, the rest wait behind the edge slot.
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

    @Test("The overflow track scrolls what does not fit")
    func overflowTrackScrolls() {
        // 8 single-window tracks, 700 pt / 300 min (gap 10) → 2
        // columns fit, so w1..w7 merge into the far-edge overflow
        // track, whose 880 pt shows two windows at 300 pt.
        let w = ids(8)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(x: 0, y: 0, width: 700, height: 900),
                breaks: Set(w)
            ) {
                $0.minWindowSize = 300
            }
        )
        let overflowX = w.map { frames[$0]!.minX }.max()!
        let overflow = w.filter { frames[$0]!.minX == overflowX }
        #expect(overflow.count == 7)
        // Two slots drawn; the five hidden share the last one.
        #expect(Set(overflow.map { frames[$0]!.minY }).count == 2)
        #expect(frames[w[7]] == frames[w[2]])
    }

    @Test("A normal track scrolls the same way")
    func normalTrackScrolls() {
        // Two tracks that both fit (no merge, so no overflow
        // track). Track 0 holds six windows and shows two.
        let w = ids(7)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(x: 0, y: 0, width: 700, height: 900),
                breaks: [w[0], w[6]]
            ) {
                $0.minWindowSize = 300
            }
        )
        let track0 = Array(w[0..<6])
        #expect(Set(track0.map { frames[$0]!.minY }).count == 2)
        #expect(frames[w[5]] == frames[w[1]])
    }

    @Test("A fixed limit shows N tracks, the last the overflow")
    func fixedCapOverflowTrack() {
        // auto off, limit 3 on a wide screen: 2 normal tracks
        // (w0, w1) + the overflow track (w2..w4) as the far-edge
        // column — three on screen, the number typed (#1354) —
        // even though more would fit. The limit is
        // display-agnostic; geometry only reduces below it.
        let w = ids(5)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(x: 0, y: 0, width: 3000, height: 900),
                breaks: Set(w)
            ) {
                $0.minWindowSize = 300
                $0.track.autoTracks = false
                $0.track.limit = 3
            }
        )
        let xs = w.map { frames[$0]!.minX }
        #expect(Set(xs).count == 3)  // the limit, overflow counted
        let overflowX = xs.max()!
        let inOverflow = w.filter { frames[$0]!.minX == overflowX }
        #expect(Set(inOverflow) == Set(w[2...]))
        // Two fit in 880 pt; the third waits behind the second.
        #expect(frames[w[4]] == frames[w[3]])
        #expect(frames[w[2]] != frames[w[3]])
    }
}
