import KiwiDeskCore
import SwiftUI

/// How `TrackSchematic` turns a window count into tracks — the
/// arithmetic half of #708, split from the drawing at the §2.1
/// ceiling.
///
/// Every RULE here is the engine's: `TrackLayout.spillsToNewTrack`
/// decides each fill-or-spill step and `TrackLayout.overflowCap`
/// folds the far edge, exactly as a real spawn and a real render
/// do. What this file owns is the loop around them, and the two
/// stand-ins for quantities a mini-canvas cannot measure
/// (`LayoutSchematicStandIns`). `LayoutSchematicTrackFoldTests`
/// reads these directly, since no source scan can tell a live
/// fold from one whose answer is discarded.
extension TrackSchematic {
    /// Windows already open — the count less the incoming one.
    private var established: Int { max(1, windows - 1) }

    /// The staged params, so the cap rules are read off the type
    /// that owns them (`trackCap`, `normalCap`) rather than
    /// re-spelled as `limit + 1` here — the drift `TrackParams`
    /// says in its own docstring it exists to prevent.
    private var params: TrackParams {
        var p = TrackParams()
        p.autoTracks = autoTracks
        p.limit = max(1, limit)
        return p
    }

    /// How the established windows fall into tracks, **asked of
    /// the engine's own rule at every step** (#708).
    ///
    /// This is the fill-then-spill the preview used to not model
    /// (#437): a window joins the focused track until that track
    /// holds `spillCapacity`, and then — while another track
    /// fits under `trackCap` — the next one opens a NEW track
    /// beside it and the focus follows. `own_track` needs no
    /// fold: every window opens its own, always (#192).
    ///
    /// The decision itself is `TrackLayout.spillsToNewTrack`,
    /// which `Space.insertIntoTrack` calls for a real spawn. A
    /// copy of the condition here would be right today and wrong
    /// the day the rule moved, which is #702's whole argument —
    /// so the loop below owns the ARITHMETIC and the engine owns
    /// the RULE.
    ///
    /// Internal so `LayoutSchematicTrackFoldTests` can read the
    /// partition: a source scan cannot tell a live fold from one
    /// whose result is discarded.
    var markerTracks: (counts: [Int], focus: Int) {
        guard newWindow == .focusedTrack else {
            // Every window its own track; the newest holds focus.
            return (
                Array(repeating: 1, count: established),
                established - 1
            )
        }
        var counts = [1]
        var focus = 0
        for _ in 1..<max(1, established) {
            if TrackLayout.spillsToNewTrack(
                focusedTrackCount: counts[focus],
                trackCount: counts.count,
                spillCapacity: LayoutSchematic.trackSpillCapacity,
                trackCap: params.trackCap
            ) {
                counts.insert(1, at: focus + 1)
                focus += 1
            } else {
                counts[focus] += 1
            }
        }
        return (counts, focus)
    }

    /// The render's normal/overflow fold, asked of the engine
    /// (`TrackLayout.overflowCap`) against the two caps: the
    /// user's own `normalCap`, and `trackGeoCap` standing in for
    /// how many tracks a display fits.
    private var fold: (effectiveCap: Int, overflows: Bool) {
        TrackLayout.overflowCap(
            markerCount: markerTracks.counts.count,
            normalCap: params.normalCap,
            // The stand-in fills in ONLY where the user gave no
            // number — the `gridAutoSizeCap` precedent, whose
            // doc says it in as many words: "with auto-size off
            // no stand-in is needed, the ceiling is the user's
            // own typed columns × rows". With a fixed limit the
            // typed value IS the ceiling, so passing the
            // stand-in here answered a typed 6 with four tracks
            // (architect review, 2026-08-16).
            geoCap: autoTracks
                ? LayoutSchematic.trackGeoCap : .max
        )
    }

    /// Whether the far-edge overflow track is on the frame. The
    /// caption reads this too: it named the overflow track
    /// unconditionally while the strip drew one only sometimes,
    /// so at the shipped defaults the preview asserted a track
    /// that was not there (#708).
    var drawsOverflowTrack: Bool { overflowWindows > 0 }

    /// Normal tracks — every marker track when nothing folds,
    /// otherwise the effective cap less the one far-edge slot the
    /// surplus folds into.
    var trackCount: Int {
        let f = fold
        return max(
            1,
            f.overflows ? f.effectiveCap - 1 : f.effectiveCap
        )
    }

    /// Windows piled in the far-edge overflow track: everything
    /// in the marker tracks the fold left outside the normal run.
    var overflowWindows: Int {
        let marker = markerTracks.counts
        guard fold.overflows, trackCount < marker.count else {
            return 0
        }
        return marker[trackCount...].reduce(0, +)
    }

    /// Windows in the focused track — the run of the track the
    /// strip actually draws as focused (`focusIdx`), clamped to
    /// what the canvas can legibly stack.
    ///
    /// Reading `counts[markerTracks.focus]` while the strip drew
    /// some other slot is what made the two disagree; the run
    /// and the slot now come from one index.
    ///
    /// The CLAMP is the drawing's; the run itself is the
    /// engine's fold — the two are separate on purpose
    /// (`LayoutSchematicStandIns`).
    var focusedRun: Int {
        let counts = markerTracks.counts
        let index = focusIdx
        let run = index < counts.count ? counts[index] : 1
        return min(4, max(1, run))
    }
}
