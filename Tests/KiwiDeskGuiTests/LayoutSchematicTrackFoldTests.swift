import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the Track preview models, and what it may therefore say
/// (#708).
///
/// The preview used to draw a behaviour the app does not have.
/// `TrackParams.NewWindowTrack.focusedTrack` is **fill-then-spill**
/// (#437): a window joins the focused track until that track holds
/// as many as fit at `min_window_size`, then — while another track
/// fits under `trackCap` — the next one opens a NEW track beside
/// it. The schematic modelled neither half, so dragging the window
/// count grew the focused track to a drawn ceiling and piled
/// everything past it into the overflow track. A user reading the
/// preview learned a rule KiwiDesk does not follow, which is the
/// one thing a live preview exists to prevent.
///
/// **These assert the arithmetic, never that the source mentions
/// the engine.** A schematic can call `spillsToNewTrack` and throw
/// the answer away; `LayoutSchematicCountTests`' header records
/// the guard-prover run that proved a source scan cannot see the
/// difference. So the fold is read directly, across the whole
/// slider band, both `autoTracks` arms and the limit range.
///
/// The two display quantities the canvas cannot compute are named
/// stand-ins (`LayoutSchematicStandIns`), and the last test here
/// holds the property that makes them legitimate: they do not
/// vary with `SchematicScale`, so a thumbnail and a panel never
/// draw two different capacities from one configuration (#712).
///
/// `@MainActor` because the quantities are properties of a `View`.
@Suite("Layout preview track fold")
@MainActor
struct LayoutSchematicTrackFoldTests {
    private func track(
        limit: Int,
        windows: Int,
        auto: Bool = false,
        rule: TrackParams.NewWindowTrack = .ownTrack,
        scale: SchematicScale = .tile
    ) -> TrackSchematic {
        TrackSchematic(
            axis: .vertical,
            overflowStyle: .cascadeAll,
            newWindow: rule,
            placement: .last,
            limit: limit,
            autoTracks: auto,
            windows: windows,
            scale: scale
        )
    }

    /// `own_track` opens a track per window, always (#192) — so
    /// the focused track holds exactly one, at every count. The
    /// old model drew four here, which was the fiction: it lumped
    /// the surplus into the focused track under a rule that never
    /// puts a second window in any track.
    @Test("own_track keeps every track a single window")
    func ownTrackRunsAreOne() {
        for count in LayoutSchematic.windowCountRange {
            for limit in 1...8 {
                #expect(
                    track(limit: limit, windows: count).focusedRun
                        == 1
                )
            }
        }
    }

    /// The rule the preview was missing. Under `focused_track`
    /// the run fills to the stand-in capacity and then a track
    /// opens beside it — so the run is bounded by the capacity
    /// wherever another track can still open, and only a space
    /// that has run out of tracks may exceed it.
    @Test("focused_track fills to capacity, then spills")
    func focusedTrackFillsThenSpills() {
        let capacity = LayoutSchematic.trackSpillCapacity
        for count in LayoutSchematic.windowCountRange {
            let auto = track(
                limit: 3,
                windows: count,
                auto: true,
                rule: .focusedTrack
            )
            // Auto-tracks never runs out (`trackCap == 0`), so
            // the focused run can never exceed the capacity.
            let marker = auto.markerTracks
            #expect(marker.counts[marker.focus] <= capacity)
            // And it genuinely spilled rather than growing one
            // track: past the capacity there is a second track.
            if count - 1 > capacity {
                #expect(marker.counts.count > 1)
            }
        }
    }

    /// The other arm of the same rule: with `auto_tracks` off the
    /// space CAN run out of tracks, and at that point the engine
    /// piles into the focused track instead of spilling
    /// (`TrackParams.NewWindowTrack.focusedTrack`'s overflow
    /// fallback). A preview that clamped the run to the capacity
    /// unconditionally would be wrong in the other direction.
    @Test("a capped space piles once it cannot spill")
    func cappedSpacePiles() {
        let schematic = track(
            limit: 1,
            windows: 12,
            rule: .focusedTrack
        )
        let marker = schematic.markerTracks
        // trackCap == limit + 1 == 2, so tracks stop at two and
        // the rest of the eleven established windows pile.
        #expect(marker.counts.count == 2)
        #expect(
            marker.counts.reduce(0, +) == 11,
            "every established window is in some track"
        )
        #expect(
            marker.counts[marker.focus]
                > LayoutSchematic.trackSpillCapacity
        )
    }

    /// The render fold, against the user's own limit. A typed
    /// limit must come back as that many normal tracks wherever
    /// there are windows to open them — a preview answering a
    /// typed 4 with three tracks is a stand-in binding where it
    /// must not.
    @Test("the drawn normal tracks honour the typed limit")
    func normalTracksHonourTheLimit() {
        for limit in 1...4 {
            #expect(
                track(limit: limit, windows: 12).trackCount
                    == limit
            )
        }
        // Tracks never outnumber the windows that open them.
        #expect(track(limit: 4, windows: 2).trackCount == 1)
    }

    /// The overflow track exists exactly when something overflows
    /// — never as a reserved far edge — and `drawsOverflowTrack`
    /// is the one answer both the strip and the caption read, so
    /// the words cannot claim a track the frame omits.
    @Test("the overflow track and its clause agree, always")
    func overflowClauseMatchesTheFrame() {
        for rule in [
            TrackParams.NewWindowTrack.ownTrack, .focusedTrack,
        ] {
            for auto in [true, false] {
                for count in LayoutSchematic.windowCountRange {
                    let s = track(
                        limit: 3,
                        windows: count,
                        auto: auto,
                        rule: rule
                    )
                    #expect(
                        s.drawsOverflowTrack
                            == (s.overflowWindows > 0)
                    )
                }
            }
        }
        // Nothing overflows two windows, under any rule.
        #expect(!track(limit: 3, windows: 2).drawsOverflowTrack)
        // And a fixed limit swamped with windows does.
        #expect(track(limit: 2, windows: 12).drawsOverflowTrack)
    }

    /// Every established window lands somewhere: the normal
    /// tracks plus the pile account for all of them. A fold that
    /// dropped windows would leave every count above green while
    /// the strip drew fewer windows than the slider says.
    @Test("the fold conserves the windows")
    func foldConservesWindows() {
        for rule in [
            TrackParams.NewWindowTrack.ownTrack, .focusedTrack,
        ] {
            for auto in [true, false] {
                for count in LayoutSchematic.windowCountRange {
                    let s = track(
                        limit: 3,
                        windows: count,
                        auto: auto,
                        rule: rule
                    )
                    #expect(
                        s.markerTracks.counts.reduce(0, +)
                            == count - 1
                    )
                }
            }
        }
    }

    /// The property that makes a stand-in legitimate rather than
    /// a clamp: one configuration folds identically at every
    /// scale. #712 shipped the opposite — a rigid 8 × 1 drew a
    /// two-window pile on the thumbnail and none in the panel,
    /// inventing an overflow the engine does not have.
    @Test("the fold does not vary with the drawing scale")
    func foldIsScaleIndependent() {
        for rule in [
            TrackParams.NewWindowTrack.ownTrack, .focusedTrack,
        ] {
            for auto in [true, false] {
                for count in LayoutSchematic.windowCountRange {
                    let tile = track(
                        limit: 3,
                        windows: count,
                        auto: auto,
                        rule: rule,
                        scale: .tile
                    )
                    let panel = track(
                        limit: 3,
                        windows: count,
                        auto: auto,
                        rule: rule,
                        scale: .panel
                    )
                    #expect(
                        tile.markerTracks.counts
                            == panel.markerTracks.counts
                    )
                    #expect(
                        tile.trackCount == panel.trackCount
                    )
                    #expect(
                        tile.overflowWindows
                            == panel.overflowWindows
                    )
                }
            }
        }
    }
}
