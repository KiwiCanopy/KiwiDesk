import AppKit
import CoreGraphics
import Foundation

/// The retile-time heal's second pass (#1355): `geometricCap`
/// made the tracks' learned floors fit, this makes the tracks
/// draw them — and no wider than their learned ceilings (#1488),
/// so a fixed-size window's surplus goes to its neighbours
/// instead of standing empty beside it. Called from
/// `healSessionWeights` in `KiwiCore+WeightHeal.swift` after its
/// shave, on the same partition and span.
extension KiwiCore {
    /// The across-axis store against each track's LEARNED floor
    /// and ceiling; the floor reading is the cap's own
    /// (`learnedFloor`), the ceiling the one `trackCeiling` the
    /// resize clamp reads too.
    func healTrackFloors(
        of space: Space,
        tiled: [WindowID],
        ranges: [Range<Int>],
        vertical: Bool,
        bounds: CGRect,
        gaps: Gaps,
        context: LayoutContext
    ) {
        guard ranges.count > 1, !context.probesBeyondBounds,
            !context.sizeBounds.isEmpty
        else { return }
        let current = state.workspaces[space.id] ?? space
        let weights = ranges.map {
            TrackLayout.weight(
                ofTrack: $0,
                tiled: tiled,
                weights: current.trackWeights
            )
        }
        let floors = ranges.map { range in
            Double(
                tiled[range].map {
                    TrackLayout.learnedFloor(of: $0, in: context)
                }.max() ?? 0
            )
        }
        let ceilings = ranges.map { range -> Double in
            TrackLayout.trackCeiling(of: tiled[range], in: context)
                .map(Double.init) ?? .infinity
        }
        let span = TrackLayout.acrossSpan(
            region: Double(
                vertical ? bounds.width : bounds.height
            ),
            gaps: gaps,
            vertical: vertical,
            count: ranges.count
        )
        guard
            let healed = TrackLayout.flooredWeights(
                weights: weights,
                span: span,
                floors: floors,
                ceilings: ceilings,
                globalFloor: Double(context.minWindowSize),
                margin: StackLayout.minSizeMargin
            )
        else { return }
        var raised = 0
        for (track, range) in ranges.enumerated()
        where healed[track] != weights[track] {
            guard
                let head = TrackLayout.localHead(
                    ofTrack: range,
                    tiled: tiled,
                    members: space.windows
                )
            else { continue }
            state.workspaces.withSpace(space.id) {
                $0.trackWeights[head] = healed[track]
            }
            raised += 1
        }
        if raised > 0 {
            onLog(
                "track weights re-shared for space \(space.id): "
                    + "\(raised) track(s) moved to draw a learned "
                    + "bound"
            )
        }
    }

}
