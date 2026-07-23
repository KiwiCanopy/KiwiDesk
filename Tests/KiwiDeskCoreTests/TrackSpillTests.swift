import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Fill-then-spill spawning for the `focused_track` default
/// (#437): a new window fills the focused track until it can't fit
/// another at min size, then spills into a new track beside it;
/// the pile survives only as the no-alternative fallback.
private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private let allTiled: @Sendable (WindowID) -> Bool = { _ in true }

private let zeroGaps = Gaps(
    outer: Gaps.Outer(top: 0, bottom: 0, left: 0, right: 0),
    inner: Gaps.Inner(horizontal: 0, vertical: 0)
)

@Suite("Track fill-then-spill (#437)")
struct TrackSpillTests {
    // MARK: Capacity & seed (pure geometry)

    @Test("Capacity is fitCap on the in-track axis")
    func capacityPicksInTrackAxis() {
        // A vertical track (column) stacks down the height; a
        // horizontal track (row) runs along the width. Zero gaps,
        // min 200: height 600 → 3, width 1200 → 6.
        var vTrack = TrackParams()
        vTrack.axis = .vertical
        let vertical = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 600),
            gaps: zeroGaps,
            minWindowSize: 200,
            track: vTrack
        )
        #expect(TrackLayout.trackCapacity(for: vertical) == 3)

        var hTrack = TrackParams()
        hTrack.axis = .horizontal
        let horizontal = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 600),
            gaps: zeroGaps,
            minWindowSize: 200,
            track: hTrack
        )
        #expect(TrackLayout.trackCapacity(for: horizontal) == 6)
    }

    @Test("No minimum makes the track unbounded (never spills)")
    func capacityUnboundedWithoutMinimum() {
        let context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 600),
            gaps: zeroGaps,
            minWindowSize: 0
        )
        #expect(TrackLayout.trackCapacity(for: context) == .max)
    }

    @Test("fillSeed packs the tiled list into tracks of capacity")
    func fillSeedPacks() {
        let w = ids(5)
        // Capacity 2 → breaks at 0, 2, 4: [w0 w1][w2 w3][w4].
        #expect(
            TrackLayout.fillSeed(tiled: w, capacity: 2)
                == Set([w[0], w[2], w[4]])
        )
    }

    @Test("A capacity past the count seeds one track")
    func fillSeedSingleTrack() {
        let w = ids(3)
        #expect(
            TrackLayout.fillSeed(tiled: w, capacity: 9) == [w[0]]
        )
    }

    // MARK: Spill on spawn (pure state)

    @Test("Fills the focused track, then spills a new one")
    func fillsThenSpills() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0]],
            focused: w[0],
            trackBreaks: [w[0]]
        )
        // Capacity 2, track holds 1 < 2 → w1 joins.
        space.insertIntoTrack(
            w[1],
            rule: .focusedTrack,
            position: .last,
            spillCapacity: 2,
            trackCap: 0,
            isTiled: allTiled
        )
        space.focused = w[1]
        #expect(space.trackBreaks == [w[0]])
        // Track now holds 2 >= 2 → w2 spills into a NEW track.
        space.insertIntoTrack(
            w[2],
            rule: .focusedTrack,
            position: .last,
            spillCapacity: 2,
            trackCap: 0,
            isTiled: allTiled
        )
        #expect(space.windows == [w[0], w[1], w[2]])
        #expect(space.trackBreaks == [w[0], w[2]])
    }

    @Test("After a spill the new track fills next (recursion)")
    func spillRecursion() {
        let w = ids(4)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1]],
            focused: w[1],
            trackBreaks: [w[0]]
        )
        // Full track (2 >= 2) → w2 spills; focus follows it.
        space.insertIntoTrack(
            w[2],
            rule: .focusedTrack,
            position: .last,
            spillCapacity: 2,
            trackCap: 0,
            isTiled: allTiled
        )
        space.focused = w[2]
        #expect(space.trackBreaks == [w[0], w[2]])
        // The new track holds 1 < 2 → w3 fills it, no spill.
        space.insertIntoTrack(
            w[3],
            rule: .focusedTrack,
            position: .last,
            spillCapacity: 2,
            trackCap: 0,
            isTiled: allTiled
        )
        #expect(space.windows == [w[0], w[1], w[2], w[3]])
        #expect(space.trackBreaks == [w[0], w[2]])
    }

    @Test("A fixed cap with no room piles instead of spilling")
    func fixedCapPiles() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1]],
            focused: w[1],
            trackBreaks: [w[0]]
        )
        // Track full (2 >= 2) but trackCap 1 leaves no room for a
        // new track → w2 joins and piles in the focused track.
        space.insertIntoTrack(
            w[2],
            rule: .focusedTrack,
            position: .last,
            spillCapacity: 2,
            trackCap: 1,
            isTiled: allTiled
        )
        #expect(space.windows == [w[0], w[1], w[2]])
        #expect(space.trackBreaks == [w[0]])
    }

    @Test("A traveler (nil capacity) always joins, never spills")
    func nilCapacityJoins() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1]],
            focused: w[1],
            trackBreaks: [w[0]]
        )
        // No spill capacity → the explicit placement joins and
        // piles, however full the track is.
        space.insertIntoTrack(
            w[2],
            rule: .focusedTrack,
            position: .last,
            spillCapacity: nil,
            trackCap: 0,
            isTiled: allTiled
        )
        #expect(space.trackBreaks == [w[0]])
    }

    // MARK: Mode-entry seed

    @Test("Entering track uses the caller's fill-then-spill seed")
    func setModeUsesProvidedSeed() {
        var manager = WorkspaceManager()
        manager.ensureSpace("1")
        let w = ids(4)
        for id in w { manager.add(id, to: "1") }
        // The KiwiCore layer packs the seed with the display
        // capacity; here it is passed directly (capacity 2).
        manager.setMode(
            "1",
            .track,
            trackSeed: TrackLayout.fillSeed(tiled: w, capacity: 2)
        )
        #expect(manager["1"]?.trackBreaks == [w[0], w[2]])
    }
}
