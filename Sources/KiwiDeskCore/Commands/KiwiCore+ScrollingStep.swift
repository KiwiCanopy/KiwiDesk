import Foundation

/// The Scrolling row's array-order step (#147), split out of
/// `KiwiCore+NavigateCommand` for file size.
extension KiwiCore {
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
    /// the axis (slot positions are monotonic in array index),
    /// so the tiled search fails and only the float tier (#488)
    /// can answer; pinned twins are all tiled, so the
    /// fall-through can never land on one.
    func scrollingStep(
        _ direction: Direction,
        space: Space,
        focused: WindowID,
        swapping: Bool,
        warp: Bool
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
        let tiled = state.effectiveTiledMembers(of: space)
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
            if refuseSwapOntoTraveler(target, in: space) {
                return .ok()
            }
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
            // A scroll gesture passes false: a pointer moved
            // mid-gesture would carry it off its own screen.
            focusWindow(target, warp: warp)
        }
        return .ok()
    }
}
