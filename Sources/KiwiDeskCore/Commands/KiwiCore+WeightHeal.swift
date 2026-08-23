import AppKit
import CoreGraphics
import Foundation

/// The retile-time session-weight heal (#944), beside the
/// interactive clamps whose authorities it shares
/// (`KiwiCore+ResizeLimits`, `KiwiCore+TrackResize`).
extension KiwiCore {
    /// Re-checks every track space's stored session weights
    /// against its CURRENT membership and span, and shaves the
    /// extremes that no longer fit (#944). The write-time clamps
    /// (#933) validate against the membership at press time; a
    /// track joining afterwards (a spawn with `own_track`, a
    /// `move_to_track`), a member joining a track, or the span
    /// shrinking (display change, wake to a smaller screen) can
    /// leave a legally-written weight squeezing the smallest
    /// share below `min_window_size` — and the layouts answer
    /// that by collapsing the WHOLE group into an overlap pile,
    /// which live QA read as "resize is broken", not physics.
    ///
    /// Called from `KiwiCore.retile` — the one choke point every
    /// membership, span and mode change already passes through —
    /// so no membership-change site owes an explicit heal call
    /// and no arm/latch state exists to go stale. Idempotent:
    /// healed weights pass the feasibility check, so the next
    /// retile is a no-op. `StackLayout.healedWeights` owns the
    /// math (and when a pile is honest and stays); this file
    /// owns which stores are healed — the per-track head weights
    /// and each track column's window shares. Stack-mode zone
    /// shares are deliberately NOT healed here — the ruling and
    /// the residue are in `docs/design-decisions.md`, recorded
    /// in `docs/accepted-limitations.md`.
    ///
    /// Two derivation rulings, both different from the clamps'
    /// and both deliberate:
    ///
    /// - **The RENDER's folded partition, not the clamp's
    ///   per-marker one.** The heal exists to keep the render's
    ///   own cascade check satisfied, so it reasons over exactly
    ///   the counts, weights and span that check reads
    ///   (`overflowCap` over `geometricCap`). Per-marker counts
    ///   — the clamp's "tighter in the safe direction" — invert
    ///   here: under a geometry-driven fold the per-marker span
    ///   fails the heal's own count×minimum guard, the heal
    ///   declines, and the folded render still piles on the
    ///   stored extreme — the #944 symptom, permanent; and the
    ///   converse over-shave rewrites stored weights whose
    ///   folded render tiles fine.
    /// - **LOCAL members, never the traveler-injected list.** A
    ///   visiting tiled-sticky window (#414 v2) is a transient
    ///   injection: healing against it would permanently rewrite
    ///   stored weights for an arrangement that departs with the
    ///   traveler — the data loss the accepted traveler rows
    ///   promise never happens. The cost is a possible transient
    ///   pile WHILE it visits, the same accepted class as the
    ///   traveler weight wobble; the heal targets the steady
    ///   state that remains.
    func healTrackSessionWeights() {
        for space in state.workspaces.allSpaces
        where space.mode == .track {
            healSessionWeights(of: space)
        }
    }

    private func healSessionWeights(of space: Space) {
        guard
            let screen = TilingEngine.screen(
                for: space.id,
                in: state
            )
        else { return }
        let bounds = tiler.layoutBounds(on: screen)
        let params = tiler.settings.resolvedTrack(for: space.id)
        let tiled = state.localTiledMembers(of: space)
        guard !tiled.isEmpty else { return }
        let markerCount = TrackLayout.counts(
            of: tiled,
            breaks: space.trackBreaks,
            cap: 0
        ).count
        // The render's effective cap needs the geometric fit,
        // which reads the usable rect — built the way
        // `trackCapacity` builds it.
        let context = tiler.settings.context(
            bounds: bounds,
            space: space,
            sticky: []
        )
        let (effectiveCap, _) = TrackLayout.overflowCap(
            markerCount: markerCount,
            normalCap: params.normalCap,
            geoCap: TrackLayout.geometricCap(for: context)
        )
        let counts = TrackLayout.counts(
            of: tiled,
            breaks: space.trackBreaks,
            cap: effectiveCap
        )
        let ranges = TrackLayout.ranges(of: counts)
        let vertical = params.axis == .vertical
        let gaps = tiler.settings.gaps(for: space.id)
        let minSize = Double(tiler.settings.minWindowSize)
        healTrackWeights(
            of: space,
            tiled: tiled,
            ranges: ranges,
            vertical: vertical,
            bounds: bounds,
            gaps: gaps,
            minSize: minSize
        )
        for range in ranges {
            healColumnShares(
                of: space,
                column: tiled[range],
                vertical: vertical,
                bounds: bounds,
                gaps: gaps,
                minSize: minSize
            )
        }
    }

    /// The across-axis store: per-track head weights
    /// (`Space.trackWeights`) against the span the tracks
    /// divide — the #944 measured collapse.
    private func healTrackWeights(
        of space: Space,
        tiled: [WindowID],
        ranges: [Range<Int>],
        vertical: Bool,
        bounds: CGRect,
        gaps: Gaps,
        minSize: Double
    ) {
        guard ranges.count > 1 else { return }
        let weights = ranges.map {
            TrackLayout.weight(
                ofTrack: $0,
                tiled: tiled,
                weights: space.trackWeights
            )
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
            let healed = StackLayout.healedWeights(
                weights: weights,
                span: span,
                minSize: minSize
            )
        else { return }
        var shaved = 0
        for (track, range) in ranges.enumerated()
        where healed[track] != weights[track] {
            // Over LOCAL tiled members `localHead` is simply the
            // slice's first window — kept for the one-copy
            // keying rule it shares with the clamp, whose input
            // can carry a traveler this one cannot.
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
            shaved += 1
        }
        if shaved > 0 {
            // A silent heal removes the symptom that makes the
            // defect findable (#599's lesson) — say what moved.
            onLog(
                "track weights healed for space \(space.id): "
                    + "\(shaved) track(s) shaved to fit "
                    + "\(ranges.count) tracks"
            )
        }
    }

    /// The along-axis store: one track column's per-window
    /// shares (`Space.stackWeights`) against the span its
    /// members divide — the same defect one level down: a
    /// window joining the column makes a stored extreme share
    /// pile the column's tail.
    private func healColumnShares(
        of space: Space,
        column: ArraySlice<WindowID>,
        vertical: Bool,
        bounds: CGRect,
        gaps: Gaps,
        minSize: Double
    ) {
        guard column.count > 1 else { return }
        let weights = column.map {
            max(
                space.stackWeights[$0] ?? 1,
                TrackLayout.weightFloor
            )
        }
        let span = TrackLayout.alongSpan(
            region: Double(
                vertical ? bounds.height : bounds.width
            ),
            gaps: gaps,
            vertical: vertical,
            count: column.count
        )
        guard
            let healed = StackLayout.healedWeights(
                weights: weights,
                span: span,
                minSize: minSize
            )
        else { return }
        var shaved = 0
        // `enumerated()` counts from zero regardless of the
        // slice's own indices, so `offset` addresses the
        // parallel `weights`/`healed` arrays directly. No
        // traveler guard here on purpose: `tiled` is the LOCAL
        // membership (the ruling above), so every member is in
        // `space.windows` by construction — the clamp keeps its
        // own guard because its input can carry a traveler.
        for (offset, member) in column.enumerated() {
            guard healed[offset] != weights[offset]
            else { continue }
            state.workspaces.withSpace(space.id) {
                $0.stackWeights[member] = healed[offset]
            }
            shaved += 1
        }
        if shaved > 0 {
            onLog(
                "window shares healed for space \(space.id): "
                    + "\(shaved) share(s) shaved to fit "
                    + "\(column.count) windows in a track"
            )
        }
    }
}
