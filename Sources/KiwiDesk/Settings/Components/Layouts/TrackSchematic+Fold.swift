import KiwiDeskCore
import SwiftUI

/// Track partitioning and overflow folding arithmetic for `TrackSchematic`
/// (#708).
extension TrackSchematic {
    /// Windows already open — count less incoming window.
    private var established: Int { max(1, windows - 1) }

    /// Staged parameters for cap calculations (`TrackParams`).
    private var params: TrackParams {
        var p = TrackParams()
        p.autoTracks = autoTracks
        p.limit = limit
        return p
    }

    /// Evaluates track partition using engine's fill-or-spill rule
    /// (`LayoutSchematicTrackFoldTests`, #708, #437, #192, #702).
    var markerTracks: (counts: [Int], focus: Int) {
        guard newWindow == .focusedTrack else {
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

    /// The marker tracks the engine would fold: under `own_track`
    /// the incoming window opens a track of its own BEFORE the
    /// render folds, so it is spliced in here and counted against
    /// the cap — drawn outside the fold it was one column past
    /// the limit (#1354). `incoming` is its index, nil under
    /// `focused_track`, where the `+` nests in the focused track.
    var foldedTracks: (counts: [Int], focus: Int, incoming: Int?) {
        let marker = markerTracks
        guard newWindow == .ownTrack else {
            return (marker.counts, marker.focus, nil)
        }
        var counts = marker.counts
        let at = SchematicPlacement.splice(
            placement,
            count: counts.count,
            focus: marker.focus
        ).incoming
        counts.insert(1, at: at)
        let focus = at <= marker.focus ? marker.focus + 1 : marker.focus
        return (counts, focus, at)
    }

    /// Overflow cap resolution for schematic preview (architect review
    /// 2026-08-16), over the tracks the engine would fold.
    private var fold: (effectiveCap: Int, overflows: Bool) {
        TrackLayout.overflowCap(
            markerCount: foldedTracks.counts.count,
            normalCap: params.normalCap,
            geoCap: autoTracks
                ? LayoutSchematic.trackGeoCap : .max
        )
    }

    /// Whether overflow track is rendered on frame (#708).
    var drawsOverflowTrack: Bool { overflowWindows > 0 }

    /// Number of normal visible tracks.
    var trackCount: Int {
        let f = fold
        return max(
            1,
            f.overflows ? f.effectiveCap - 1 : f.effectiveCap
        )
    }

    /// Number of windows pooled in far-edge overflow track.
    var overflowWindows: Int {
        let counts = foldedTracks.counts
        guard fold.overflows, trackCount < counts.count else {
            return 0
        }
        return counts[trackCount...].reduce(0, +)
    }

    /// Whether the incoming `own_track` window's track itself
    /// folds into the overflow — a `last` placement past the cap.
    var incomingFolds: Bool {
        guard let at = foldedTracks.incoming else { return false }
        return at >= trackCount
    }

    /// Windows in focused track clamped for preview drawing
    /// (`LayoutSchematicStandIns`).
    var focusedRun: Int {
        let counts = foldedTracks.counts
        let index = focusIdx
        let run = index < counts.count ? counts[index] : 1
        return min(4, max(1, run))
    }
}
