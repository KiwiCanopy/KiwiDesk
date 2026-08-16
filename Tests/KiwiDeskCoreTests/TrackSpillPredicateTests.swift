import Foundation
import Testing

@testable import KiwiDeskCore

/// `TrackLayout.spillsToNewTrack` against the spawn it was
/// extracted from (#708).
///
/// The predicate became public so a Settings preview and a real
/// spawn could share one rule rather than the preview carrying a
/// copy — the #702 class. That extraction is only worth anything
/// while the predicate still describes what `insertIntoTrack`
/// does, and every direct assertion on it landed in the GUI test
/// target (architect review, 2026-08-16). This is the Core-side
/// half: the predicate is pinned against the SPAWN's own
/// behaviour, so a change to either that leaves them disagreeing
/// reds here rather than in a preview.
@Suite("Track spill predicate (#437, #708)")
struct TrackSpillPredicateTests {
    private let allTiled: @Sendable (WindowID) -> Bool = { _ in
        true
    }

    /// Builds a track space by inserting `count` windows under
    /// `rule`, focus following each new window the way a real
    /// spawn's caller does.
    private func space(
        count: Int,
        capacity: Int?,
        trackCap: Int
    ) -> Space {
        var space = Space(id: "1", mode: .track)
        for i in 1...count {
            let window = WindowID(UInt32(i))
            space.insertIntoTrack(
                window,
                rule: .focusedTrack,
                position: .last,
                spillCapacity: capacity,
                trackCap: trackCap,
                isTiled: allTiled
            )
            space.focused = window
        }
        return space
    }

    private func counts(_ space: Space) -> [Int] {
        TrackLayout.counts(
            of: space.windows,
            breaks: space.trackBreaks,
            cap: 0
        )
    }

    /// The predicate's answer IS the spawn's behaviour: wherever
    /// it says spill, the next insert opens a track; wherever it
    /// says join, the track count holds.
    @Test("the predicate predicts what the spawn does")
    func predicatePredictsTheSpawn() {
        for capacity in 1...4 {
            for count in 1...10 {
                var s = space(
                    count: count,
                    capacity: capacity,
                    trackCap: 0
                )
                let before = counts(s)
                let focusIndex = s.focused.flatMap { f in
                    s.windows.firstIndex(of: f)
                }
                let track =
                    focusIndex.flatMap {
                        TrackLayout.trackIndex(
                            ofWindowIndex: $0,
                            counts: before
                        )
                    } ?? before.count - 1
                let predicted = TrackLayout.spillsToNewTrack(
                    focusedTrackCount: before[track],
                    trackCount: before.count,
                    spillCapacity: capacity,
                    trackCap: 0
                )
                let next = WindowID(UInt32(count + 1))
                s.insertIntoTrack(
                    next,
                    rule: .focusedTrack,
                    position: .last,
                    spillCapacity: capacity,
                    trackCap: 0,
                    isTiled: allTiled
                )
                let opened = counts(s).count > before.count
                #expect(
                    predicted == opened,
                    Comment(
                        rawValue:
                            "capacity \(capacity), \(count) "
                            + "windows: predicate said "
                            + "\(predicted), spawn \(opened)"
                    )
                )
            }
        }
    }

    /// A nil capacity disables the spill entirely — the
    /// explicit-placement path (`move_to_space` travelers),
    /// which must join and pile rather than be relocated.
    @Test("no capacity means never spill")
    func nilCapacityNeverSpills() {
        for tracks in 1...5 {
            for held in 1...9 {
                #expect(
                    !TrackLayout.spillsToNewTrack(
                        focusedTrackCount: held,
                        trackCount: tracks,
                        spillCapacity: nil,
                        trackCap: 0
                    )
                )
            }
        }
    }

    /// At the cap there is nowhere to spill to, so a full track
    /// piles instead — the overflow fallback `TrackParams`
    /// documents on `focusedTrack`.
    @Test("a capped space piles instead of spilling")
    func cappedSpacePiles() {
        // trackCap 2, already at 2 tracks, focused track full.
        #expect(
            !TrackLayout.spillsToNewTrack(
                focusedTrackCount: 3,
                trackCount: 2,
                spillCapacity: 3,
                trackCap: 2
            )
        )
        // Room for one more track: spills.
        #expect(
            TrackLayout.spillsToNewTrack(
                focusedTrackCount: 3,
                trackCount: 1,
                spillCapacity: 3,
                trackCap: 2
            )
        )
        // trackCap 0 is unlimited (auto-tracks), so it always
        // spills once full — the arm a fixed cap never reaches.
        #expect(
            TrackLayout.spillsToNewTrack(
                focusedTrackCount: 3,
                trackCount: 99,
                spillCapacity: 3,
                trackCap: 0
            )
        )
    }
}
