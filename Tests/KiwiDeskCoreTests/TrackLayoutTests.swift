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

    @MainActor
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
        // The overflow track's run parks what it hides (#2235).
        let screen = CGRect(x: 0, y: 0, width: 2000, height: 900)
        let parked = w.filter {
            TilingEngine.looksStashed(frames[$0]!, in: screen)
        }
        let shown = w.filter { !parked.contains($0) }
        let xs = shown.map { frames[$0]!.minX }
        // Five normal columns + one overflow column = six x's.
        #expect(Set(xs).count == 6)
        // The overflow track is the far edge and holds the tail.
        let overflowX = xs.max()!
        let inOverflow = shown.filter { frames[$0]!.minX == overflowX }
        #expect(!parked.isEmpty)
        #expect(Set(inOverflow + parked) == Set(w[5...]))
        // Each leading track holds exactly one window.
        for lead in w[..<5] {
            #expect(
                xs.filter { $0 == frames[lead]!.minX }.count == 1
            )
        }
        // The overflow track scrolls (#2235): each shown window
        // draws its own slot, the last window waits parked.
        let oy = Set(inOverflow.map { frames[$0]!.minY })
        #expect(oy.count == inOverflow.count)
        #expect(parked.contains(w[w.count - 1]))
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

    @MainActor
    @Test("Along-axis overflow shows what fits, hides the rest")
    func alongAxisPartialOverflow() {
        // One track holding more windows than fit: the run shows
        // what fits and the rest wait parked.
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
        // Single track: every shown window shares one column; the
        // rest rest parked at the hide corner (#2235).
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 1600)
        let shown = w.filter {
            !TilingEngine.looksStashed(frames[$0]!, in: screen)
        }
        #expect(Set(shown.map { frames[$0]!.minX }).count == 1)
        #expect(shown.count > 1)
        #expect(shown.count < w.count)
        #expect(w.allSatisfy { frames[$0]!.height >= 300 })
        #expect(!shown.contains(w[7]))
    }

    @Test("A row's overflow waits behind its last slot")
    func overflowCascadeAlwaysVertical() {
        // Horizontal mode, one row holding too many windows: the
        // windows tile along X and the rest wait behind the
        // row's last shown slot, full height (#2235).
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
        let xs = Set(w.map { frames[$0]!.minX })
        #expect(xs.count > 1)
        #expect(xs.count < w.count)
        #expect(Set(w.map { frames[$0]!.height }).count == 1)
        #expect(frames[w[9]] == frames[w[8]])
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
