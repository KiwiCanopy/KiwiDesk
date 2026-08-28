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
    @discardableResult
    func resizeTrackMember(
        _ window: WindowID,
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) -> CommandResponse {
        let params = tiler.settings.resolvedTrack(for: space.id)
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        guard let index = tiled.firstIndex(of: window)
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
            focused: window,
            column: tiled[ranges[track]]
        )
    }

    func resizeTrack(
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) -> CommandResponse {
        // `space.focused`, not the anchor: resize keys per-window
        // weights by id, which must stay on a real member to avoid
        // orphaning under a non-member traveler (#308) — see
        // `resize` in `KiwiCore+Resize.swift`.
        guard let focused = space.focused else {
            return .fail("no focused tiled window")
        }
        return resizeTrackMember(
            focused,
            axis: axis,
            delta: delta,
            span: span,
            space: space
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
        let params = tiler.settings.resolvedTrack(for: space.id)
        let vertical = params.axis == .vertical
        let acrossAxis = vertical ? "x" : "y"
        // The layout divides the span minus the inner gaps
        // between the tracks — clamping against the raw span
        // lets the stored weight cross the layout's cascade
        // check by exactly the gaps, which is how #925's clamp
        // still collapsed the space into an overflow pile
        // (#933). Exact for the unfolded case; under an active
        // overflow fold the layout merges surplus tracks
        // (`overflowCap`) while this clamp reasons over the
        // per-marker `ranges`, so it subtracts more gaps than
        // the layout — tighter, in the safe direction: it can
        // cue a refusal early, never admit a pile. (The #944
        // heal deliberately answers the fold the other way —
        // its doc owns why.) Per-track minimums: a track spans
        // all its members across the axis, so its tightest
        // member binds it.
        let effectiveSpan = TrackLayout.acrossSpan(
            region: span,
            gaps: tiler.settings.gaps(for: space.id),
            vertical: vertical,
            count: ranges.count
        )
        let trackMins = ranges.map {
            effectiveMinSize(
                of: tiled[$0],
                axis: acrossAxis
            )
        }
        let outcome = StackLayout.weightStep(
            weights: weights,
            at: track,
            delta: delta,
            span: effectiveSpan,
            minSizes: trackMins.map(\.size)
        )
        let value = outcome.value
        if let focused = space.focused {
            if delta < 0, outcome.hitOwnMinimum {
                // The focused track's floor may be carried by a
                // track-mate with a larger learned bound — then
                // the mate is the window that cannot shrink and
                // the pill goes on it (#435's rule).
                reportResizeRefusal(
                    focused: focused,
                    bindingCarrier: trackMins[track].carrier,
                    fallbackAnchor: nil,
                    shrinking: true,
                    axis: acrossAxis
                )
            } else if delta > 0,
                let blocked = outcome.blockedByOther
            {
                let anchor =
                    trackMins[blocked].carrier
                    ?? tiled[ranges[blocked]].first(where: {
                        $0 != focused
                    })
                refuseGrowAtNeighborMinimum(
                    focused,
                    anchor: anchor ?? focused,
                    axis: acrossAxis
                )
            }
        }
        // Key the weight to the first LOCAL member of the track
        // (`localHead` owns the traveler argument). While a
        // traveler heads the track the layout still reads the
        // head's (default) weight — an accepted wobble, see
        // design-decisions.
        guard
            let head = TrackLayout.localHead(
                ofTrack: ranges[track],
                tiled: tiled,
                members: space.windows
            )
        else { return .fail("track has no local window") }
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
        // The share write keys per-window state by id: a
        // tiled-sticky traveler (#414 v2) is not in
        // `space.windows`, so an entry under its id could never
        // be pruned (orphan; recycled-id hazard, #308) — refuse
        // it, mirroring the across-track head guard above. The
        // mouse path hands the DRAGGED window, which can be a
        // traveler; the keyboard path's `space.focused` cannot.
        guard space.windows.contains(focused) else {
            return .fail(
                "the focused window is visiting from "
                    + "another Space"
            )
        }
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
        let params = tiler.settings.resolvedTrack(for: space.id)
        let vertical = params.axis == .vertical
        let alongAxis = vertical ? "y" : "x"
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
            effectiveMinSize(of: $0, axis: alongAxis)
        }
        let outcome = StackLayout.weightStep(
            weights: weights,
            at: index,
            delta: delta,
            span: effectiveSpan,
            minSizes: minSizes
        )
        if delta < 0, outcome.hitOwnMinimum {
            refuseShrinkAtMinimum(focused, axis: alongAxis)
        } else if delta > 0,
            let blocked = outcome.blockedByOther
        {
            refuseGrowAtNeighborMinimum(
                focused,
                anchor: members[blocked],
                axis: alongAxis
            )
        }
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[focused] = outcome.value
        }
        return .ok()
    }
}
