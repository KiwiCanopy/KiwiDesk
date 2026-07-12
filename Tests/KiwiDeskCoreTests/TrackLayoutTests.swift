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

@Suite("Track partition (#128)")
struct TrackPartitionTests {
    @Test("Breaks split the tiled list; index 0 is implicit")
    func breaksSplit() {
        let w = ids(6)
        #expect(
            TrackLayout.counts(
                of: w,
                breaks: [w[2], w[3]],
                cap: 0
            ) == [2, 1, 3]
        )
    }

    @Test("No breaks means one track holding everything")
    func noBreaksOneTrack() {
        #expect(
            TrackLayout.counts(of: ids(3), breaks: [], cap: 0)
                == [3]
        )
    }

    @Test("A break on a window not in the list does not split")
    func floatingBreakInvisible() {
        let w = ids(4)
        // w[1] floats (not in the tiled list): its marker is
        // dormant, the remaining windows partition without it.
        let tiled = [w[0], w[2], w[3]]
        #expect(
            TrackLayout.counts(
                of: tiled,
                breaks: [w[1], w[2]],
                cap: 0
            ) == [1, 2]
        )
    }

    @Test("Tracks past the cap merge into the last allowed one")
    func capMergesTail() {
        let w = ids(4)
        #expect(
            TrackLayout.counts(
                of: w,
                breaks: [w[1], w[2], w[3]],
                cap: 2
            ) == [1, 3]
        )
    }

    @Test("Zero windows yield no tracks")
    func emptyWindows() {
        #expect(
            TrackLayout.counts(of: [], breaks: [], cap: 0)
                .isEmpty
        )
    }

    @Test("ranges carve consecutive slices")
    func rangesSlices() {
        #expect(
            TrackLayout.ranges(of: [2, 1, 3])
                == [0..<2, 2..<3, 3..<6]
        )
        #expect(
            TrackLayout.trackIndex(
                ofWindowIndex: 2,
                counts: [2, 1, 3]
            ) == 1
        )
        #expect(
            TrackLayout.trackIndex(
                ofWindowIndex: 6,
                counts: [2, 1, 3]
            ) == nil
        )
    }

    @Test("A track's weight is its head window's entry")
    func headWeight() {
        let w = ids(3)
        #expect(
            TrackLayout.weight(
                ofTrack: 1..<3,
                tiled: w,
                weights: [w[1]: 2.5]
            ) == 2.5
        )
        // Absent = even share.
        #expect(
            TrackLayout.weight(
                ofTrack: 0..<1,
                tiled: w,
                weights: [:]
            ) == 1
        )
    }
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

    @Test("cascade_overflow tiles the fitting tracks, piles rest")
    func crossAxisPartialOverflow() {
        // 10 single-window tracks on a wide screen: some fit at
        // min size, the rest cascade — not the whole space.
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
        // A fitting prefix of columns is tiled full-height; the
        // overflow columns pile as a VERTICAL title-bar cascade
        // (min height, +40 px DOWNWARD steps) — never a
        // horizontal pile (title bars must stay visible).
        let tiled = w.filter { frames[$0]!.height > 300.5 }
        let cascaded = w.filter { frames[$0]!.height <= 300.5 }
        #expect(!tiled.isEmpty)
        #expect(!cascaded.isEmpty)
        // The tiled prefix spreads across distinct x positions
        // (not a whole-space pile).
        #expect(Set(tiled.map { frames[$0]!.minX }).count == tiled.count)
        // The cascade tail steps DOWN in y, at a shared x.
        let tailYs = cascaded.map { frames[$0]!.minY }.sorted()
        let tailXs = Set(cascaded.map { frames[$0]!.minX })
        #expect(tailXs.count == 1)
        if tailYs.count >= 2 {
            #expect(abs((tailYs[1] - tailYs[0]) - 40) < 0.001)
        }
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
                // cascade_overflow keeps a tiled prefix; the
                // track default (cascade_all) piles everything.
                $0.track.overflowStyle = .cascadeOverflow
            }
        )
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
                $0.track.overflowStyle = .cascadeOverflow
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
