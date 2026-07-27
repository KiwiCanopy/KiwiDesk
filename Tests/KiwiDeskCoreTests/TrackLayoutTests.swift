import CoreGraphics
import Testing

@testable import KiwiDeskCore

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
    breaks: Set<WindowID> = [],
    weights: [WindowID: Double] = [:],
    tune: (inout LayoutContext) -> Void = { _ in }
) -> LayoutContext {
    var context = LayoutContext(
        bounds: bounds,
        gaps: .uniform(10),
        trackBreaks: breaks,
        trackWeights: weights
    )
    tune(&context)
    return context
}

@Suite("Track layout geometry (#128)")
struct TrackLayoutTests {
    let layout = TrackLayout()

    @Test("Vertical axis lays tracks out as columns")
    func verticalColumns() {
        let w = ids(3)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(breaks: [w[1], w[2]])
        )
        let f1 = frames[w[0]]!
        let f2 = frames[w[1]]!
        let f3 = frames[w[2]]!
        // Full height, side by side, separated by the gap.
        #expect(f1.height == f2.height && f2.height == f3.height)
        #expect(f1.maxX + 10 == f2.minX)
        #expect(f2.maxX + 10 == f3.minX)
        // Even weights: equal widths.
        #expect(abs(f1.width - f3.width) < 0.001)
    }

    @Test("Horizontal axis lays tracks out as rows")
    func horizontalRows() {
        let w = ids(2)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(breaks: [w[1]]) {
                $0.track.axis = .horizontal
            }
        )
        let f1 = frames[w[0]]!
        let f2 = frames[w[1]]!
        #expect(f1.width == f2.width)
        #expect(f1.maxY + 10 == f2.minY)
    }

    @Test("A head weight widens exactly that track")
    func trackWeightWidens() {
        let w = ids(2)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(breaks: [w[1]], weights: [w[0]: 3])
        )
        let f1 = frames[w[0]]!
        let f2 = frames[w[1]]!
        #expect(abs(f1.width - 3 * f2.width) < 0.001)
    }

    @Test("stackWeights split a track's windows along the axis")
    func inTrackShares() {
        let w = ids(3)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(breaks: [w[1]]) {
                $0.stackWeights = [w[1]: 3]
                // Keep the 1:3 shares above the cascade cliff.
                $0.minWindowSize = 100
            }
        )
        let f2 = frames[w[1]]!
        let f3 = frames[w[2]]!
        // Same column: stacked vertically, weighted 3:1.
        #expect(f2.minX == f3.minX)
        #expect(abs(f2.height - 3 * f3.height) < 0.001)
    }

    @Test("Tracks below min size cascade the whole space")
    func minSizeCascade() {
        let w = ids(8)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(
                    x: 0,
                    y: 0,
                    width: 800,
                    height: 600
                ),
                breaks: Set(w)
            ) {
                $0.minWindowSize = 300
            }
        )
        // 8 columns in 800 pt cannot honor 300 pt: overlap
        // cascade keeps every window at least min-sized.
        for id in w {
            #expect(frames[id]!.width >= 300)
        }
    }

    @Test("Surplus tracks merge into one far-edge overflow track")
    func overflowTrackMerge() {
        // 10 single-window tracks, 2000 pt / 300 min (gap 10) →
        // 6 columns fit. The first five tile one window each; the
        // surplus (w5..w9) merges into the sixth, far-edge
        // overflow track (default cascade_all → piled), instead
        // of scattering as separate cascaded columns.
        let w = ids(10)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(
                    x: 0,
                    y: 0,
                    width: 2000,
                    height: 900
                ),
                breaks: Set(w)
            ) {
                $0.minWindowSize = 300
            }
        )
        let xs = w.map { frames[$0]!.minX }
        // Five normal columns + one overflow column = six x's.
        #expect(Set(xs).count == 6)
        // The overflow track is the far edge and holds the tail.
        let overflowX = xs.max()!
        let inOverflow = w.filter { frames[$0]!.minX == overflowX }
        #expect(Set(inOverflow) == Set(w[5...]))
        // Each leading track holds exactly one window.
        for lead in w[..<5] {
            #expect(
                xs.filter { $0 == frames[lead]!.minX }.count == 1
            )
        }
        // cascade_all piles the overflow windows: they step down
        // in y at the shared far-edge x.
        let oy = inOverflow.map { frames[$0]!.minY }.sorted()
        #expect(abs((oy[1] - oy[0]) - 40) < 0.001)
    }

    @Test("Degenerate span falls back to a whole-space cascade")
    func degenerateSpanWholeCascade() {
        // A space too narrow to tile even one min-size column:
        // the internal physics fallback cascades the whole
        // space (#180 — hard-coded, no overflow knob).
        let w = ids(10)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(
                    x: 0,
                    y: 0,
                    width: 400,
                    height: 900
                ),
                breaks: Set(w)
            ) {
                $0.minWindowSize = 300
            }
        )
        // Every window gets the full usable width (the
        // whole-region OverlapStack), none tiled narrow.
        let widths = Set(w.map { frames[$0]!.width })
        #expect(widths.count == 1)
        #expect(widths.first! >= 300)
    }

    @Test("Along-axis overflow tiles the fitting prefix too")
    func alongAxisPartialOverflow() {
        // One track holding many windows taller than fits: the
        // prefix tiles, the rest cascade within the column.
        let w = ids(8)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(
                    x: 0,
                    y: 0,
                    width: 1200,
                    height: 1600
                ),
                breaks: [w[0]]
            ) {
                $0.minWindowSize = 300
            }
        )
        // A single (normal) track always cascade_overflows its
        // own windows: a tiled prefix, then a pile.
        // Single track: all windows share one column (same x).
        #expect(Set(w.map { frames[$0]!.minX }).count == 1)
        let tiled = w.filter { frames[$0]!.height > 300.5 }
        let cascaded = w.filter { frames[$0]!.height <= 300.5 }
        #expect(!tiled.isEmpty)
        #expect(!cascaded.isEmpty)
    }

    @Test("Overflow always cascades vertically, even in rows")
    func overflowCascadeAlwaysVertical() {
        // Horizontal mode, one row holding too many windows:
        // the windows tile along X, and the overflow piles as a
        // DOWNWARD title-bar cascade (shared y-offset
        // convention) — not a horizontal side-sliver pile.
        let w = ids(10)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(
                bounds: CGRect(
                    x: 0,
                    y: 0,
                    width: 2400,
                    height: 700
                ),
                breaks: [w[0]]
            ) {
                $0.track.axis = .horizontal
                $0.minWindowSize = 300
            }
        )
        let cascaded = w.filter { frames[$0]!.height <= 300.5 }
        #expect(!cascaded.isEmpty)
        // The buried windows step DOWN in y at a shared x — a
        // vertical cascade, not horizontal.
        let ys = cascaded.map { frames[$0]!.minY }.sorted()
        #expect(Set(cascaded.map { frames[$0]!.minX }).count == 1)
        if ys.count >= 2 {
            #expect(abs((ys[1] - ys[0]) - 40) < 0.001)
        }
    }

    @Test("Empty window list yields no frames")
    func emptyWindows() {
        #expect(
            layout.calculateGeometry(
                for: [],
                in: makeContext()
            ).isEmpty
        )
    }
}
