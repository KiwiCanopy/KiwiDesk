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
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        guard let index = tiled.firstIndex(of: focused) else {
            return .fail("no focused tiled window")
        }
        // The overflow track is a read-time merge (#192): its
        // folded slices have no marker identity, so exchanging
        // them by marker would re-derive a different composition
        // (windows leak across tracks; #182 review H1). The
        // merge fires under BOTH a fixed limit and geometric
        // pressure (auto tracks on, small display), so gauge it
        // against the render's own cap — geometry included, read
        // from the live layout context (#198). No context (no
        // screen, headless) degrades to the fixed-limit cap.
        let geoCap =
            (tiler.layoutInput(state: state)?.context)
            .map(TrackLayout.geometricCap(for:)) ?? .max
        if TrackLayout.overflowSwapBlocked(
            tiled: tiled,
            breaks: space.trackBreaks,
            windowIndex: index,
            delta: delta,
            normalCap: params.normalCap,
            geoCap: geoCap
        ) {
            return .fail(
                "track.swap can't reorder the folded overflow "
                    + "track — raise the track limit or free "
                    + "display space so it stops folding"
            )
        }
        // Swap on the render's effective partition so what moves
        // matches what the user sees (identical to `trackCap`
        // absent geometric pressure).
        let effectiveCap = TrackLayout.overflowCap(
            markerCount: TrackLayout.counts(
                of: tiled,
                breaks: space.trackBreaks,
                cap: 0
            ).count,
            normalCap: params.normalCap,
            geoCap: geoCap
        ).effectiveCap
        var swapped = false
        state.workspaces.withSpace(space.id) {
            swapped = $0.swapTracks(
                focused,
                delta: delta,
                cap: effectiveCap,
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
        scheduleTrackZOrderRestoreIfOverflowing()
        return .ok()
    }
}
