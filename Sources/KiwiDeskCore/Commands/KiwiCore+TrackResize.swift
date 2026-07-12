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
        let params = tiler.settings.resolvedTrack(for: space.id)
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard let focused = space.focused,
            let index = tiled.firstIndex(of: focused)
        else { return .fail("no focused tiled window") }
        let counts = TrackLayout.counts(
            of: tiled,
            breaks: space.trackBreaks,
            cap: params.trackCap
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

    /// Grows the focused window's track via `weightStep` (the
    /// shared #67/#128 authority) over the per-head track
    /// weights.
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
        let value = StackLayout.weightStep(
            weights: weights,
            at: track,
            delta: delta,
            span: span,
            minSize: Double(tiler.settings.minWindowSize)
        )
        let head = tiled[ranges[track].lowerBound]
        state.workspaces.withSpace(space.id) {
            $0.trackWeights[head] = value
        }
        return .ok()
    }

    /// Grows the focused window's share within its track — the
    /// same `weightStep` authority over the per-window
    /// `stackWeights`, with the track slice standing in for the
    /// master/stack column.
    private func resizeTrackShare(
        delta: Double,
        span: Double,
        space: Space,
        focused: WindowID,
        column: ArraySlice<WindowID>
    ) -> CommandResponse {
        guard let offset = column.firstIndex(of: focused),
            column.count > 1
        else {
            // In default 1D track (#181) every window fills its
            // track, so this fires on every along-axis resize —
            // phrase it as "use the other axis", not an error
            // about tracks the user never authored (#183).
            return .fail(
                "the focused window fills its track along "
                    + "this axis — resize across the tracks "
                    + "to change its size"
            )
        }
        let weightFloor = TrackLayout.weightFloor
        let weights = column.map {
            max(space.stackWeights[$0] ?? 1, weightFloor)
        }
        let index = column.distance(
            from: column.startIndex,
            to: offset
        )
        let value = StackLayout.weightStep(
            weights: weights,
            at: index,
            delta: delta,
            span: span,
            minSize: Double(tiler.settings.minWindowSize)
        )
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[focused] = value
        }
        return .ok()
    }
}
