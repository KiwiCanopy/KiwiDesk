import Foundation

/// `track.swap` (#182): a directional command swapping the
/// focused window's **entire track** (contiguous slice) with
/// the adjacent one. Complements window-level `swap` — two
/// windows there, two tracks here — following the
/// `stack.promote`/`stack.demote` precedent for layout-specific
/// whole-structure verbs. Split from `KiwiCore+TrackNavigate`
/// for file size.
extension KiwiCore {
    func trackSwap(_ args: [JSONValue]) -> CommandResponse {
        // prev/next like `move_to_track` — the sequence
        // vocabulary; see `trackSequenceDelta`.
        guard let raw = args.first?.stringValue,
            let delta = Self.trackSequenceDelta(raw)
        else {
            return .fail("expected prev|next")
        }
        guard let space = activeSpace else {
            return .fail("no active space")
        }
        guard space.mode == .track else {
            return .fail("track.swap needs a track space")
        }
        guard let focused = space.focused,
            state.windows[focused]?.isFloating == false
        else {
            return .fail("no focused tiled window")
        }
        let params = tiler.settings.resolvedTrack(for: space.id)
        // Snapshot float verdicts first: the withSpace closure
        // must not touch `state` while it is being mutated.
        let floating = Set(
            space.windows.filter {
                state.windows[$0]?.isFloating == true
            }
        )
        // The cap merge is a read-time VIEW (#178): while it is
        // folding extra tracks into the last slot, the merged
        // slices have no marker identity — exchanging them
        // reorders the array but the re-derived merge produces
        // a different composition (windows leak across tracks;
        // review H1). Rewriting markers to pin the view would
        // destroy the grandfathered partition, so reject.
        let tiled = space.windows.filter {
            !floating.contains($0)
        }
        let unmerged = TrackLayout.counts(
            of: tiled,
            breaks: space.trackBreaks,
            cap: 0
        )
        if params.trackCap > 0,
            unmerged.count > params.trackCap
        {
            return .fail(
                "track.swap is unavailable while the track "
                    + "limit folds extra tracks — raise the "
                    + "limit or turn automatic tracks on"
            )
        }
        var swapped = false
        state.workspaces.withSpace(space.id) {
            swapped = $0.swapTracks(
                focused,
                delta: delta,
                cap: params.trackCap,
                isTiled: { !floating.contains($0) }
            )
        }
        guard swapped else {
            return .fail("no \(raw) track of focus")
        }
        // Self-retile with the window-swap animation toggle,
        // exactly like `move_to_track` — the two sibling track
        // reorder verbs must share one animation policy
        // (review: riding layoutCommand's trailing forced
        // retile put this one under `on_relayout` instead).
        // Dispatched directly from `execute`, so no dispatcher
        // retile follows.
        retile(
            animated: tiler.settings.animations.onWindowSwap
        )
        return .ok()
    }
}
