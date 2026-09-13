import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Track's automatic count reads the members' learned minimums
/// (#1355): the cap is the largest prefix whose tracks — each at
/// the larger of `min_window_size` and its members' corroborated
/// floor on the cross axis — fit the span with their gaps. The
/// display is pinned (#531), and so is `min_window_size`, which
/// every expectation below reasons from (#660).
@Suite("Track automatic cap honours learned minimums (#1355)")
struct TrackLearnedCapTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)

    /// 1000×800 with 10 pt gaps: a 980 pt cross span for vertical
    /// tracks (780 for horizontal), three tracks at the 300 pt
    /// floor fitting side by side (three own-track markers).
    private func makeContext() -> LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 800),
            gaps: .uniform(10)
        )
        context.minWindowSize = 300
        context.trackBreaks = [w2, w3]
        // The defaults every expectation reasons from (#660).
        context.track.axis = .vertical
        context.track.autoTracks = true
        return context
    }

    /// A corroborated floor at `span`: two distinct asks answered
    /// above themselves with one span (#933).
    private func floor(_ span: CGFloat) -> [EffectiveSizeBound.Axis] {
        [
            .init(asked: 250, answered: span),
            .init(asked: 200, answered: span),
        ]
    }

    @Test("Nothing learned answers the plain fit")
    func nothingLearnedIsFitCap() {
        let context = makeContext()
        let plain = TrackLayout.fitCap(
            crossSpan: context.usable.width,
            minSize: 300,
            gap: 10
        )
        #expect(plain == 3)
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 3
        )
    }

    @Test("A corroborated floor tightens the automatic cap")
    func learnedFloorTightens() {
        var context = makeContext()
        // 600 + 300 + 300 + two gaps = 1220 > 980: three do not
        // fit; 600 + 300 + one gap = 910 fits — two tracks.
        context.sizeBounds = [
            w1: EffectiveSizeBound(width: floor(600))
        ]
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 2
        )
    }

    @Test("A window with no bound counts at min_window_size")
    func unboundMemberCountsAtGlobalFloor() {
        var context = makeContext()
        // 400 + 300 + 300 + two gaps = 1020 > 980 only because
        // the two unbound members count at the global minimum;
        // at nothing they would still fit three.
        context.sizeBounds = [
            w1: EffectiveSizeBound(width: floor(400))
        ]
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 2
        )
    }

    @Test("A floor below min_window_size counts at the minimum")
    func floorBelowGlobalCountsAtGlobal() {
        var context = makeContext()
        // A 100 pt floor: two asks BELOW it answered with it (the
        // helper's asks would sit above 100 and read as a
        // ceiling). 300 (not 100) + 500 + 300 + two gaps = 1120
        // > 980: two tracks; read at its own 100 the three fit.
        context.sizeBounds = [
            w1: EffectiveSizeBound(width: [
                .init(asked: 80, answered: 100),
                .init(asked: 60, answered: 100),
            ]),
            w2: EffectiveSizeBound(width: floor(500)),
        ]
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 2
        )
    }

    @Test("The gaps between the tracks count against the span")
    func gapsCountAgainstTheSpan() {
        var context = makeContext()
        // 675 + 300 = 975 fits 980 without the gap between them
        // and 985 does not with it: one track.
        context.sizeBounds = [
            w1: EffectiveSizeBound(width: floor(675))
        ]
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 1
        )
    }

    @Test("A forced pass probes past the learned floors")
    func forcedPassProbesPastFloors() {
        var context = makeContext()
        context.sizeBounds = [
            w1: EffectiveSizeBound(width: floor(600))
        ]
        context.probesBeyondBounds = true
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 3
        )
    }

    @Test("A fixed limit stays the user's number")
    func fixedLimitIgnoresLearnedFloors() {
        var context = makeContext()
        context.track.autoTracks = false
        context.track.limit = 3
        context.sizeBounds = [
            w1: EffectiveSizeBound(width: floor(600))
        ]
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 3
        )
    }

    @Test("Horizontal tracks read the height floor, not the width")
    func horizontalTracksReadHeight() {
        var context = makeContext()
        context.track.axis = .horizontal
        // 780 pt cross span: two 300 pt rows fit (610), three do
        // not (920).
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 2
        )
        context.sizeBounds = [
            w1: EffectiveSizeBound(width: floor(600))
        ]
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 2
        )
        context.sizeBounds = [
            w1: EffectiveSizeBound(height: floor(600))
        ]
        // 600 + 300 + one gap = 910 > 780: one row.
        #expect(
            TrackLayout.geometricCap(
                for: context,
                of: [w1, w2, w3]
            ) == 1
        )
    }

    @Test("The render folds on the learned cap")
    func renderFoldsOnLearnedCap() throws {
        var context = makeContext()
        context.sizeBounds = [
            w1: EffectiveSizeBound(width: floor(600))
        ]
        let frames = TrackLayout().calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let f1 = try #require(frames[w1])
        let f2 = try #require(frames[w2])
        let f3 = try #require(frames[w3])
        // Two tracks: the second and third windows share the
        // overflow track's column instead of each taking one.
        #expect(f1.minX != f2.minX)
        #expect(f2.minX == f3.minX)
    }
}
