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
    /// and each track column's window shares, mirroring the
    /// resize paths' span and keying rules exactly. Stack-mode
    /// zone shares are deliberately NOT healed here — the ruling
    /// and the residue are in `docs/design-decisions.md`.
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
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        guard !tiled.isEmpty else { return }
        // The per-marker partition the interactive clamp reasons
        // over (`resizeTrackWeight`) — under an active overflow
        // fold this counts more gaps than the render, which is
        // tighter in the safe direction (#933's argument).
        let counts = TrackLayout.counts(
            of: tiled,
            breaks: space.trackBreaks,
            cap: params.trackCap
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
        let gap =
            vertical
            ? gaps.inner.horizontal : gaps.inner.vertical
        let outer =
            vertical
            ? gaps.outer.left + gaps.outer.right
            : gaps.outer.top + gaps.outer.bottom
        let span = StackLayout.weightedSpan(
            region: Double(vertical ? bounds.width : bounds.height),
            outer: Double(outer),
            innerGap: Double(gap),
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
            // The head-keying rule and its traveler guard are
            // `resizeTrackWeight`'s: key the first LOCAL member,
            // and skip a track a traveler heads outright.
            guard
                let head = tiled[range].first(where: {
                    space.windows.contains($0)
                })
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
        let gap =
            vertical
            ? gaps.inner.vertical : gaps.inner.horizontal
        let outer =
            vertical
            ? gaps.outer.top + gaps.outer.bottom
            : gaps.outer.left + gaps.outer.right
        let span = StackLayout.weightedSpan(
            region: Double(vertical ? bounds.height : bounds.width),
            outer: Double(outer),
            innerGap: Double(gap),
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
        // parallel `weights`/`healed` arrays directly.
        for (offset, member) in column.enumerated() {
            guard healed[offset] != weights[offset],
                // The membership guard is `resizeTrackShare`'s:
                // never write under a traveler's id (orphan;
                // recycled-id hazard, #308).
                space.windows.contains(member)
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
