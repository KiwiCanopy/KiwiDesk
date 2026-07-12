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
        guard let raw = args.first?.stringValue,
            let direction = Direction(rawValue: raw)
        else {
            return .fail("expected left|right|up|down")
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
        // In default 1D track every track is a single window, so
        // a whole-track swap degenerates to the plain `swap`
        // that already exists — gated like `move_to_track`, with
        // the same pointer (#181).
        guard isTrackAdvanced else {
            return .fail(Self.trackAdvancedHint)
        }
        let params = effectiveTrack(for: space.id)
        let vertical = params.axis == .vertical
        let delta: Int
        switch direction {
        case .left where vertical, .up where !vertical:
            delta = -1
        case .right where vertical, .down where !vertical:
            delta = 1
        default:
            return .fail(
                "track.swap swaps across the tracks — "
                    + (vertical
                        ? "expected left|right"
                        : "expected up|down")
            )
        }
        // Snapshot float verdicts first: the withSpace closure
        // must not touch `state` while it is being mutated.
        let floating = Set(
            space.windows.filter {
                state.windows[$0]?.isFloating == true
            }
        )
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
            return .fail("no track \(raw) of focus")
        }
        // The reorder's retile is the dispatcher's trailing
        // `retile(force:)` (`layoutCommand`), like
        // promote/demote.
        return .ok()
    }
}
