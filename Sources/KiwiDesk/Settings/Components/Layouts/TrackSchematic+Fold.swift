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
        p.limit = max(1, limit)
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

    /// Overflow cap resolution for schematic preview (architect review
    /// 2026-08-16).
    private var fold: (effectiveCap: Int, overflows: Bool) {
        TrackLayout.overflowCap(
            markerCount: markerTracks.counts.count,
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
        let marker = markerTracks.counts
        guard fold.overflows, trackCount < marker.count else {
            return 0
        }
        return marker[trackCount...].reduce(0, +)
    }

    /// Windows in focused track clamped for preview drawing
    /// (`LayoutSchematicStandIns`).
    var focusedRun: Int {
        let counts = markerTracks.counts
        let index = focusIdx
        let run = index < counts.count ? counts[index] : 1
        return min(4, max(1, run))
    }
}
