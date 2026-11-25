import AppKit
import Foundation

/// The along-track half of a Track resize, split out of
/// `KiwiCore+TrackResize` for file size; its name keeps it in the
/// resize refusal census (`ResizeRefusalCensusTests`).
extension KiwiCore {
    /// Grows the focused window's share within its track — the
    /// same `weightStep` authority over the per-window
    /// `stackWeights`, with the track slice standing in for the
    /// master/stack column.
    func resizeTrackShare(
        delta: Double,
        span: Double,
        space: Space,
        focused: WindowID,
        // Whether the ACROSS axis divides, which is the press
        // to send the user to when this one cannot (#1258).
        tracks: Int,
        column: ArraySlice<WindowID>,
        toward side: RunZone.PushSide
    ) -> CommandResponse {
        // The share write keys per-window state by id: a
        // tiled-sticky traveler (#414 v2) is not in
        // `space.windows`, so an entry under its id could never
        // be pruned (orphan; recycled-id hazard, #308) — refuse
        // it, mirroring the across-track head guard in
        // `resizeTrackWeight`. The mouse path hands the DRAGGED
        // window, which can be a traveler; the keyboard path's
        // `space.focused` cannot.
        guard space.windows.contains(focused) else {
            return .fail(
                "a tiled sticky window can be resized only "
                    + "in its home Space"
            )
        }
        guard let offset = column.firstIndex(of: focused),
            column.count > 1
        else {
            // In default 1D track (#181) every window fills its
            // track, so this fires on every along-axis resize —
            // phrase it as "use the other axis", not an error
            // about tracks the user never authored (#183).
            refuseNothingToDivide(
                focused,
                otherAxisDivides: tracks > 1
            )
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
        let params = tiler.settings.resolvedTrack(for: space.id)
        let vertical = params.axis == .vertical
        let alongAxis = vertical ? "y" : "x"
        if let response = resizeInRun(
            focused,
            axis: alongAxis,
            delta: delta,
            toward: side,
            space: space,
            otherAxisDivides: tracks > 1
        ) {
            return response
        }
        // Gap-adjusted span and per-window minimums, exactly as
        // the across-tracks knob above (#933): the layout
        // divides the span minus the gaps between the track's
        // windows, and each member carries its own floor.
        let effectiveSpan = TrackLayout.alongSpan(
            region: span,
            gaps: tiler.settings.gaps(for: space.id),
            vertical: vertical,
            count: column.count
        )
        let members = Array(column)
        let minSizes = members.map {
            plannedMinSize(of: $0, axis: alongAxis)
        }
        let outcome = StackLayout.weightStep(
            weights: weights,
            at: index,
            delta: delta,
            span: effectiveSpan,
            minSizes: minSizes
        )
        if pushOrCue(
            outcome,
            of: focused,
            members: members,
            axis: alongAxis,
            delta: delta,
            toward: side,
            space: space
        ) {
            return .ok()
        }
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[focused] = outcome.value
        }
        return .ok()
    }
}
