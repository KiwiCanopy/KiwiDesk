import Testing

@testable import KiwiDeskCore

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
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
