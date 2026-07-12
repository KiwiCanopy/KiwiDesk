import AppKit
import Foundation

/// Directional `focus` / `swap` navigation, split out of
/// `KiwiCore+Commands` for file size.
extension KiwiCore {
    func navigate(
        _ args: [JSONValue],
        swapping: Bool
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = Direction(rawValue: raw)
        else {
            return .fail("expected left|right|up|down")
        }
        guard let space = activeSpace,
            let focused = space.focused
        else {
            return .fail("no focused window")
        }
        // Monocle windows all share one frame, so geometric
        // neighbor search finds nothing. Directions on the
        // configured orientation axis cycle the window order
        // instead; the cross axis falls through.
        if space.mode == .monocle,
            let response = monocleCycle(
                direction,
                space: space,
                focused: focused,
                swapping: swapping
            )
        {
            return response
        }
        // Scrolling pins overflowing slots at identical edge
        // frames (#142), so geometric search ties among them
        // and picks the wrong window (#147). Directions on the
        // scroll axis step the flat array instead; the cross
        // axis falls through, like monocle.
        if space.mode == .scrolling,
            let response = scrollingStep(
                direction,
                space: space,
                focused: focused,
                swapping: swapping
            )
        {
            return response
        }
        // Track spaces step in array order too (#128): within
        // the track along the axis, across tracks on the other
        // one — pure index math, the maintainer-preferred
        // scrolling precedent. Nil falls through like above.
        if space.mode == .track,
            let response = trackStep(
                direction,
                space: space,
                focused: focused,
                swapping: swapping
            )
        {
            return response
        }
        // Navigate the layout's slots, not live AX frames:
        // live frames are stale mid-animation or when an app
        // misses a move notification, and cascaded windows
        // overlap anyway. Floating windows (no slot) fall
        // back to their last known frame.
        let slots = tiler.calculatedFrames(state: state)
        guard
            let frame = slots[focused]
                ?? state.windows[focused]?.frame
        else {
            return .fail("no focused window")
        }
        let candidates = space.windows
            .filter {
                $0 != focused
                    && state.windows[$0]?.isFloating == false
            }
            .compactMap { id -> (WindowID, CGRect)? in
                guard
                    let slot = slots[id]
                        ?? state.windows[id]?.frame
                else { return nil }
                return (id, slot)
            }
        // A swap from inside an overflow cascade must reach the
        // tiled neighbor outside the pile, not reorder the pile
        // (#172): drop the focused window's pile-mates from the
        // candidate set so the geometric search skips past them.
        // Not for `focus` — only `swap` — and only when enabled.
        var searchCandidates = candidates
        if swapping, tiler.settings.swapSkipsCascade {
            let pile = Navigation.pileMates(
                of: focused,
                among: candidates + [(focused, frame)]
            )
            if !pile.isEmpty {
                searchCandidates = candidates.filter {
                    !pile.contains($0.0)
                }
            }
        }
        guard
            let target = Navigation.neighbor(
                from: frame,
                in: direction,
                candidates: searchCandidates
            )
        else {
            return .fail("no window \(raw) of focus")
        }
        if swapping {
            let crossedZones = crossesStackBoundary(
                focused,
                target,
                in: space
            )
            state.workspaces.withSpace(space.id) {
                $0.swap(focused, target)
            }
            retile(
                animated: tiler.settings.animations.onWindowSwap
            )
            // A scrolling swap can push a window into an edge pile
            // whose stacking then goes stale (#150); a track swap
            // that fell through to the geometric search can
            // scramble a track's overflow pile (#193); a stack swap
            // that crosses the master boundary scrambles the
            // cascade. All three gates are mode-exclusive.
            if space.mode == .scrolling {
                scheduleScrollingZOrderRestoreIfOverflowing()
            } else if space.mode == .track {
                scheduleTrackZOrderRestoreIfOverflowing()
            } else if crossedZones {
                scheduleZOrderRestore()
            }
        } else {
            focusWindow(target)
        }
        return .ok()
    }

    /// Steps or reorders along the scrolling axis in array
    /// order (#147).
    ///
    /// `focus`/`swap` in the resolved orientation's directions
    /// move to the previous/next tiled index — the row is the
    /// flat array, so array order IS spatial order, and slots
    /// pinned at a shared edge sliver (#142) cannot mislead a
    /// geometric search. Past an end: `focus` wraps to the far
    /// end when `wrap_focus` is on (#168), else falls through;
    /// `swap` never wraps (a wrapping swap would teleport the
    /// window across the whole row). Nil (→ geometric
    /// navigation) for cross-axis directions, for a floating
    /// focused window, and for a non-wrapping step past the
    /// row's ends — at an end no tiled window lies further along
    /// the axis (slot positions are monotonic in array index)
    /// and floating windows are never candidates, so the
    /// geometric search cleanly fails there; it can never land
    /// on a pinned twin.
    private func scrollingStep(
        _ direction: Direction,
        space: Space,
        focused: WindowID,
        swapping: Bool
    ) -> CommandResponse? {
        let horizontal =
            tiler.settings.resolvedScrolling(for: space.id)
            .orientation == .horizontal
        let step: Int
        switch direction {
        case .left where horizontal: step = -1
        case .right where horizontal: step = 1
        case .up where !horizontal: step = -1
        case .down where !horizontal: step = 1
        default: return nil
        }
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard let index = tiled.firstIndex(of: focused)
        else { return nil }
        let targetIndex = index + step
        let target: WindowID
        if tiled.indices.contains(targetIndex) {
            target = tiled[targetIndex]
        } else if !swapping, tiled.count > 1,
            tiler.settings.resolvedScrolling(for: space.id)
                .wrapFocus,
            let wrapped = step > 0 ? tiled.first : tiled.last
        {
            // Opt-in wrap past an end (#168). The wrap keeps
            // array-index order, so the deferred-raise classifier
            // (#143/#158) reads it right without a special case:
            // wrapping forward to index 0 is a lower-index move —
            // a backward pan, raise deferred; wrapping backward to
            // the last index is a higher-index move — a forward
            // pan, raise immediate. Each matches a plain step in
            // that direction. `count > 1` skips a pointless
            // wrap-to-self on a single-window row.
            target = wrapped
        } else {
            return nil
        }
        if swapping {
            state.workspaces.withSpace(space.id) {
                $0.swap(focused, target)
            }
            retile(
                animated: tiler.settings.animations.onWindowSwap
            )
            // The array-step swap moves a window along the row and
            // can land it in an overflowing edge pile (#150).
            scheduleScrollingZOrderRestoreIfOverflowing()
        } else {
            focusWindow(target)
        }
        return .ok()
    }
}
