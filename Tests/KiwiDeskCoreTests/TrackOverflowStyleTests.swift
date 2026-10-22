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
/// many as fit are shown, the rest wait parked.
@Suite("Track overflow track (#192)")
@MainActor
struct TrackOverflowStyleTests {
    /// The windows a run parks at the hide corner (#2235).
    private func parked(
        _ frames: [WindowID: CGRect],
        on screen: CGRect
    ) -> Set<WindowID> {
        Set(
            frames.filter {
                TilingEngine.looksStashed($0.value, in: screen)
            }.keys
        )
    }

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
        let screen = CGRect(x: 0, y: 0, width: 700, height: 900)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(bounds: screen, breaks: Set(w)) {
                $0.minWindowSize = 300
            }
        )
        let hidden = parked(frames, on: screen)
        let shown = w.filter { !hidden.contains($0) }
        let overflowX = shown.map { frames[$0]!.minX }.max()!
        let overflow = shown.filter { frames[$0]!.minX == overflowX }
        // Two shown in their own slots; the five hidden parked.
        #expect(overflow.count == 2)
        #expect(hidden.count == 5)
        #expect(Set(overflow.map { frames[$0]!.minY }).count == 2)
        #expect(hidden.contains(w[7]))
    }

    @Test("A normal track scrolls the same way")
    func normalTrackScrolls() {
        // Two tracks that both fit (no merge, so no overflow
        // track). Track 0 holds six windows and shows two.
        let w = ids(7)
        let screen = CGRect(x: 0, y: 0, width: 700, height: 900)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(bounds: screen, breaks: [w[0], w[6]]) {
                $0.minWindowSize = 300
            }
        )
        let hidden = parked(frames, on: screen)
        let shown0 = w[0..<6].filter { !hidden.contains($0) }
        #expect(shown0.count == 2)
        #expect(Set(shown0.map { frames[$0]!.minY }).count == 2)
        #expect(hidden == Set(w[2..<6]))
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
        let hidden = parked(
            frames,
            on: CGRect(x: 0, y: 0, width: 3000, height: 900)
        )
        let shown = w.filter { !hidden.contains($0) }
        let xs = shown.map { frames[$0]!.minX }
        #expect(Set(xs).count == 3)  // the limit, overflow counted
        let overflowX = xs.max()!
        let inOverflow = shown.filter { frames[$0]!.minX == overflowX }
        // Two fit in 880 pt; the third waits parked.
        #expect(Set(inOverflow) == [w[2], w[3]])
        #expect(hidden == [w[4]])
    }
}
