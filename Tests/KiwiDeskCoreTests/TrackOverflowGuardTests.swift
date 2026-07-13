import CoreGraphics
import Testing

@testable import KiwiDeskCore

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

/// The pure overflow-fold arithmetic behind `track.swap`'s guard
/// (#192/#198). Exercised directly with injected caps so the
/// GEOMETRIC and auto-tracks fold paths — which the command
/// reaches only through a live display — are covered headlessly.
@Suite("Track overflow guard (#198)")
struct TrackOverflowGuardTests {
    @Test("effectiveCap: fixed limit adds one overflow track")
    func capFixedLimit() {
        let out = TrackLayout.overflowCap(
            markerCount: 4,
            normalCap: 2,
            geoCap: .max
        )
        #expect(out.overflows)
        #expect(out.effectiveCap == 3)
    }

    @Test("effectiveCap: geometric fit caps auto tracks")
    func capGeometric() {
        // auto_tracks on = normalCap .max, so geometry alone caps.
        let out = TrackLayout.overflowCap(
            markerCount: 5,
            normalCap: .max,
            geoCap: 2
        )
        #expect(out.overflows)
        #expect(out.effectiveCap == 2)
    }

    @Test("effectiveCap: geometry clamps a fixed limit too")
    func capGeometricUnderLimit() {
        // Limit 4 but only 2 fit: the fold is geometric, not the
        // count — the old count-only guard missed this (#198).
        let out = TrackLayout.overflowCap(
            markerCount: 4,
            normalCap: 4,
            geoCap: 2
        )
        #expect(out.overflows)
        #expect(out.effectiveCap == 2)
    }

    @Test("effectiveCap: nothing folds when all tracks fit")
    func capNoOverflow() {
        let out = TrackLayout.overflowCap(
            markerCount: 2,
            normalCap: .max,
            geoCap: 5
        )
        #expect(!out.overflows)
        #expect(out.effectiveCap == 2)
    }

    @Test("geometricCap reads the axis span and inner gap")
    func geometricCapWiring() {
        let context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            gaps: .uniform(10)
        )
        let vertical = TrackLayout.geometricCap(for: context)
        #expect(
            vertical
                == max(
                    1,
                    TrackLayout.fitCap(
                        crossSpan: context.usable.width,
                        minSize: context.minWindowSize,
                        gap: context.gaps.inner.horizontal
                    )
                )
        )
        var horiz = context
        horiz.track.axis = .horizontal
        #expect(
            TrackLayout.geometricCap(for: horiz)
                == max(
                    1,
                    TrackLayout.fitCap(
                        crossSpan: context.usable.height,
                        minSize: context.minWindowSize,
                        gap: context.gaps.inner.vertical
                    )
                )
        )
    }

    @Test("Geometric fold blocks a swap into the overflow")
    func geometricFoldBlocks() {
        // Four singleton tracks, auto on, only three fit:
        // partition [1] [1] [2], overflow slot = index 2.
        let w = ids(4)
        // Track 1 (window 2) toward the fold — blocked (#198,
        // the gap: normalCap .max means the count guard never
        // fired).
        #expect(
            TrackLayout.overflowSwapBlocked(
                tiled: w,
                breaks: Set(w),
                windowIndex: 1,
                delta: 1,
                normalCap: .max,
                geoCap: 3
            )
        )
        // The window IN the folded slot is blocked either way.
        #expect(
            TrackLayout.overflowSwapBlocked(
                tiled: w,
                breaks: Set(w),
                windowIndex: 3,
                delta: -1,
                normalCap: .max,
                geoCap: 3
            )
        )
    }

    @Test("Two normal tracks swap under a geometric fold")
    func normalTracksAllowedUnderGeometricFold() {
        // Same [1] [1] [2] fold: track 0 toward track 1 never
        // touches the overflow slot — allowed.
        let w = ids(4)
        #expect(
            !TrackLayout.overflowSwapBlocked(
                tiled: w,
                breaks: Set(w),
                windowIndex: 0,
                delta: 1,
                normalCap: .max,
                geoCap: 3
            )
        )
    }

    @Test("A lone N+1th overflow track folds nothing, swaps")
    func loneOverflowTrackAllowed() {
        // Three singleton tracks, limit 2: the third stands
        // alone as the N+1th track (no ≥2 fold), so swapping it
        // is safe.
        let w = ids(3)
        #expect(
            !TrackLayout.overflowSwapBlocked(
                tiled: w,
                breaks: Set(w),
                windowIndex: 2,
                delta: -1,
                normalCap: 2,
                geoCap: .max
            )
        )
    }
}
