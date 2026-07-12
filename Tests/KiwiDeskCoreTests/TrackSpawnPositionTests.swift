import Foundation
import Testing

@testable import KiwiDeskCore

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private let allTiled: @Sendable (WindowID) -> Bool = { _ in true }

/// `new_window_position` (#188): where a spawned window lands
/// within the `new_window` choice. `own_track` positions the new
/// track among the tracks; `focused_track` positions the window
/// among the focused track's windows. The `after_focused` cases
/// are the #128 originals, pinned in `TrackStateTests`.
@Suite("Track spawn position (#188)")
struct TrackSpawnPositionTests {
    // MARK: own_track — position among tracks

    @Test("own_track first opens a new front track")
    func ownFirst() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1]],
            focused: w[0],
            trackBreaks: [w[1]]
        )
        space.insertIntoTrack(
            w[2],
            rule: .ownTrack,
            position: .first,
            cap: 0,
            isTiled: allTiled
        )
        #expect(space.windows == [w[2], w[0], w[1]])
        // The demoted old first head becomes an explicit break.
        #expect(space.trackBreaks == [w[0], w[1], w[2]])
    }

    @Test("own_track last opens a new track at the far edge")
    func ownLast() {
        let w = ids(3)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1]],
            focused: w[0],
            trackBreaks: [w[1]]
        )
        space.insertIntoTrack(
            w[2],
            rule: .ownTrack,
            position: .last,
            cap: 0,
            isTiled: allTiled
        )
        #expect(space.windows == [w[0], w[1], w[2]])
        #expect(space.trackBreaks == [w[1], w[2]])
    }

    @Test("own_track before_focused opens a track ahead of it")
    func ownBeforeFocused() {
        let w = ids(4)
        // Three single-window tracks; focus the last.
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1], w[2]],
            focused: w[2],
            trackBreaks: [w[1], w[2]]
        )
        space.insertIntoTrack(
            w[3],
            rule: .ownTrack,
            position: .beforeFocused,
            cap: 0,
            isTiled: allTiled
        )
        // New track sits just before the focused (third) track.
        #expect(space.windows == [w[0], w[1], w[3], w[2]])
        #expect(space.trackBreaks == [w[1], w[2], w[3]])
    }

    // MARK: focused_track — position among the track's windows

    @Test("focused_track first takes over the track head")
    func joinFirst() {
        let w = ids(4)
        // One track [w0,w1,w2] (w0 the implicit head), focus w1.
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1], w[2]],
            focused: w[1],
            trackBreaks: []
        )
        space.insertIntoTrack(
            w[3],
            rule: .focusedTrack,
            position: .first,
            cap: 0,
            isTiled: allTiled
        )
        // Still one track, but w3 is now its head.
        #expect(space.windows == [w[3], w[0], w[1], w[2]])
        #expect(space.trackBreaks == [w[3]])
    }

    @Test("focused_track last appends to the track")
    func joinLast() {
        let w = ids(4)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1], w[2]],
            focused: w[1],
            trackBreaks: []
        )
        space.insertIntoTrack(
            w[3],
            rule: .focusedTrack,
            position: .last,
            cap: 0,
            isTiled: allTiled
        )
        #expect(space.windows == [w[0], w[1], w[2], w[3]])
        #expect(space.trackBreaks == [])
    }

    @Test("focused_track before_focused inserts ahead of focus")
    func joinBeforeFocused() {
        let w = ids(4)
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1], w[2]],
            focused: w[1],
            trackBreaks: []
        )
        space.insertIntoTrack(
            w[3],
            rule: .focusedTrack,
            position: .beforeFocused,
            cap: 0,
            isTiled: allTiled
        )
        #expect(space.windows == [w[0], w[3], w[1], w[2]])
        #expect(space.trackBreaks == [])
    }

    @Test("Taking the head transfers the track's weight")
    func headTakesWeight() {
        let w = ids(3)
        // Two tracks: [w0 | w1,w2], the second headed by w1
        // carrying a cross-axis weight; focus w1 and join first.
        var space = Space(
            id: "1",
            mode: .track,
            windows: [w[0], w[1], w[2]],
            focused: w[1],
            trackBreaks: [w[1]]
        )
        space.trackWeights = [w[1]: 3.0]
        let w3 = WindowID(4)
        space.insertIntoTrack(
            w3,
            rule: .focusedTrack,
            position: .first,
            cap: 0,
            isTiled: allTiled
        )
        // w3 heads the second track now and carries its weight;
        // the demoted w1 keeps neither marker nor weight.
        #expect(space.windows == [w[0], w3, w[1], w[2]])
        #expect(space.trackBreaks == [w3])
        #expect(space.trackWeights[w3] == 3.0)
        #expect(space.trackWeights[w[1]] == nil)
    }
}
