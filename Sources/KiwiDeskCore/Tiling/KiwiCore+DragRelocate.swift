import AppKit
import Foundation

/// Cross-display drop: a tiled drag released over a slot on
/// ANOTHER display MOVES the window to that display, rather than
/// swapping the two (#492). Dropping a window onto a different
/// monitor is a relocation — "put this window over there" — which
/// is what people reach for; a same-display drop still swaps.
///
/// This is a SECOND window-relocation path beside `moveWindow`
/// (which backs the keyboard / Space-Bar move and runs the #207
/// space-switch animation + warp, both wrong when the destination
/// space is already on-screen). No parity test binds the two, so
/// keep its focus / event / z-order obligations in sync by hand
/// with `moveWindow`'s follow branch and the same-space swap in
/// `handleDragEnd`: whatever they honor after a re-home
/// (`emitWindowMovedToSpace`, the #463 settle, the overflow
/// z-order restore) this must honor too.
extension KiwiCore {
    /// Handles a tiled drop whose cursor ends on a DIFFERENT
    /// display than the dragged window. The window moves into the
    /// display-under-the-cursor's active space, and the focused
    /// display follows the drop there. In a geometric / array-order
    /// layout, dropping over a window (`target`) lands on that slot
    /// — the target and everything after it shift down one. A track
    /// space instead treats the arrival like a new window (its
    /// `new_window` rule), and a drop over empty space just receives
    /// it. Either way, dropping over another display *moves the
    /// window there* (#492).
    ///
    /// Returns `true` when it took the drop (the caller returns
    /// without running the same-space swap); `false` when the drop
    /// is same-display or the destination can't be resolved, so the
    /// ordinary swap / snap-back path runs.
    ///
    /// The destination is the active space of the display UNDER THE
    /// CURSOR, not `space(of: target)`: a tiled-sticky traveler is
    /// injected into a foreign display yet still belongs to its home
    /// space, so keying on the cursor's display (and only slotting
    /// `target` when it is a real member there) keeps a traveler
    /// from teleporting the window to wherever its home happens to
    /// show — a non-member target is treated as an empty drop.
    func relocateAcrossDisplay(
        _ id: WindowID,
        onto target: WindowID?,
        from origin: Space
    ) -> Bool {
        let cocoaCursor = drag.cursorLocation()
        guard
            let screen = NSScreen.screens.first(where: {
                $0.frame.contains(cocoaCursor)
            }),
            let display = screen.kiwiDisplay?.id,
            let destID = state.workspaces.activeSpace(on: display),
            destID != origin.id,
            let dest = state.workspaces[destID]
        else { return false }
        // A sticky window that can't cross displays snaps back
        // instead — the same gate a keyboard / Space-Bar move
        // honors (#445).
        if stickyMoveRefused(id, to: destID) {
            retile()
            focusWindow(id, warp: false)
            return true
        }
        // The drop lands on the destination display, so the
        // dropped window keeps OS focus there once we follow;
        // captured before the retile/focus below for the #463
        // dropped-activate settle.
        let priorFrontmost = frontmostPIDProvider?()
        // Placement. Dropping onto a WINDOW in a geometric /
        // array-order layout lands on that slot (the target and its
        // followers shift one), honoring the drop-zone the user saw.
        // Everything else — a TRACK space, or a drop over empty
        // space / no target — routes through `addFocusedToSpace`,
        // the same choke point `moveWindow` uses: a window arriving
        // on a track space follows its `new_window` rule (e.g. open
        // in a new track) exactly like a freshly spawned one, and an
        // empty destination just receives the window. Keeping this
        // one choke point also keeps track cap / spill placement out
        // of two hand-maintained copies.
        if dest.mode != .track,
            let target,
            let targetIndex = dest.windows.firstIndex(of: target)
        {
            state.workspaces.add(id, to: destID, after: target)
            state.workspaces.withSpace(destID) {
                $0.move(id, to: targetIndex)
            }
        } else {
            addFocusedToSpace(id, to: destID)
        }
        state.workspaces.focus(id, in: destID)
        // The pointer ended on the destination display; make it the
        // focused one so "current space" follows the window there —
        // #446's display-follow, driven by a drop instead of a
        // click.
        state.workspaces.activate(destID)
        emitWindowMovedToSpace(
            id,
            app: state.windows[id]?.appName ?? "",
            bundleID: state.windows[id]?.appBundleID,
            from: origin.id,
            to: destID
        )
        // Both displays reflow — origin loses a window, destination
        // gains one. A plain retile, NOT spaceSwitchRetile (#207):
        // the destination space is already on-screen, so there is no
        // space transition to coordinate, only in-place relayout on
        // each display.
        retile(animated: tiler.settings.animations.onWindowSwap)
        // Mouse-made focus, no warp — matches the same-space drop.
        focusWindow(id, warp: false)
        // The destination may be an overflowing stack / track /
        // scrolling pile; inserting a window scrambles its stacking
        // exactly as a swap does, so restore it once the retile
        // settles (§5 cross-layout obligation, #193 / #150 — the
        // twin of the same-space drop's z-order restores). Keyed on
        // the just-activated destination, so `runPendingZOrderRestore`
        // dispatches the mode-correct restore; a non-overlapping
        // destination mode falls through to a no-op.
        scheduleZOrderRestore()
        emitSpaceChange()
        // The follow hands focus to a space that was already
        // visible; re-assert once so a dropped cooperative activate
        // (#463) can't leave the destination showing the wrong key
        // window.
        scheduleSpaceSettle(destID, priorFrontmost: priorFrontmost)
        return true
    }
}
