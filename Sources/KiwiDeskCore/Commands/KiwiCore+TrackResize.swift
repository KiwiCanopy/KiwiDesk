import AppKit
import Foundation

/// Track-mode `resize` (#128), split out of `KiwiCore+Resize`
/// for file size. The axis decides the one true target: across
/// the tracks it grows the focused window's TRACK (per-head
/// weight), along them it grows the focused window's share
/// within its track (per-window `stackWeights` — the same knob
/// and formula as the stack's #67 path, via the shared domain
/// authorities, so the two layouts cannot drift apart).
extension KiwiCore {
    func resizeTrack(
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) -> CommandResponse {
        let params =
            tiler.settings.resolvedTrack(for: space.id)
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard let focused = space.focused,
            let index = tiled.firstIndex(of: focused)
        else { return .fail("no focused tiled window") }
        let counts = TrackLayout.counts(
            of: tiled,
            breaks: space.trackBreaks,
            cap: params.count
        )
        guard
            let track = TrackLayout.trackIndex(
                ofWindowIndex: index,
                counts: counts
            )
        else { return .fail("no focused tiled window") }
        let ranges = TrackLayout.ranges(of: counts)
        let vertical = params.axis == .vertical
        let acrossAxis = vertical ? "x" : "y"
        if axis == acrossAxis {
            return resizeTrackWeight(
                delta: delta,
                span: span,
                space: space,
                tiled: tiled,
                ranges: ranges,
                track: track
            )
        }
        return resizeTrackShare(
            delta: delta,
            span: span,
            space: space,
            focused: focused,
            column: tiled[ranges[track]]
        )
    }

    /// Grows the focused window's track: the weight step is the
    /// stack's #67 formula over the track weights, capped where
    /// the smallest OTHER track would drop below
    /// min_window_size (past that cliff the layout cascades and
    /// extra weight only ratchets invisibly).
    private func resizeTrackWeight(
        delta: Double,
        span: Double,
        space: Space,
        tiled: [WindowID],
        ranges: [Range<Int>],
        track: Int
    ) -> CommandResponse {
        guard ranges.count > 1 else {
            return .fail("only one track")
        }
        let weights = ranges.map {
            TrackLayout.weight(
                ofTrack: $0,
                tiled: tiled,
                weights: space.trackWeights
            )
        }
        let total = weights.reduce(0, +)
        let current = weights[track]
        let change =
            delta * total * total / (span * (total - current))
        var value = current + change
        if change > 0 {
            let others = weights.enumerated()
                .filter { $0.offset != track }
                .map(\.element)
            if let smallest = others.min() {
                let limit = StackLayout.maxColumnTotal(
                    smallestWeight: smallest,
                    height: span,
                    minSize: Double(
                        tiler.settings.minWindowSize
                    )
                )
                let cap = limit - (total - current)
                value = min(value, max(cap, current))
            }
        }
        let range = TrackLayout.weightRange
        value = min(
            max(value, range.lowerBound),
            range.upperBound
        )
        let head = tiled[ranges[track].lowerBound]
        state.workspaces.withSpace(space.id) {
            $0.trackWeights[head] = value
        }
        return .ok()
    }

    /// Grows the focused window's share within its track — the
    /// stack's per-window weight path (#67) with the track
    /// slice standing in for the master/stack column.
    private func resizeTrackShare(
        delta: Double,
        span: Double,
        space: Space,
        focused: WindowID,
        column: ArraySlice<WindowID>
    ) -> CommandResponse {
        guard column.count > 1 else {
            return .fail("focused window is alone in its track")
        }
        let weightFloor = TrackLayout.weightFloor
        let weights = column.map {
            max(space.stackWeights[$0] ?? 1, weightFloor)
        }
        let total = weights.reduce(0, +)
        let current = max(
            space.stackWeights[focused] ?? 1,
            weightFloor
        )
        let change =
            delta * total * total / (span * (total - current))
        var value = current + change
        if change > 0 {
            let others = zip(column, weights)
                .filter { $0.0 != focused }
                .map(\.1)
            if let smallest = others.min() {
                let limit = StackLayout.maxColumnTotal(
                    smallestWeight: smallest,
                    height: span,
                    minSize: Double(
                        tiler.settings.minWindowSize
                    )
                )
                let cap = limit - (total - current)
                value = min(value, max(cap, current))
            }
        }
        let range = TrackLayout.weightRange
        value = min(
            max(value, range.lowerBound),
            range.upperBound
        )
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[focused] = value
        }
        return .ok()
    }
}
