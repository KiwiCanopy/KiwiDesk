import AppKit
import Foundation

/// Cross-display drop: a tiled drag released over a slot on
/// ANOTHER display MOVES the window to that display, rather than
/// swapping the two (#492). Dropping a window onto a different
/// monitor is a relocation — "put this window over there" — which
/// is what people reach for; a same-display drop still swaps.
///
/// FOUR window-relocation paths now exist, with DELIBERATELY
/// different post-rehome obligations. No parity test can bind
/// behavior — this table is the registry; keep it honest by hand
/// when touching any of the four:
///
///   path                  AX focus   #463    z-order   retile
///                                    settle  restore   force
///   moveWindow(follow:)   yes+warp   yes*    —         yes*
///   Space-Bar spring      none       none    none      yes
///   live crossing (#504)  none       none    yes       yes
///   drop-commit (below)   no-warp    yes     yes       no
///
///   *follow only: `spaceSwitchRetile` (forced) + the #463
///    settle. The no-follow branch retiles un-forced, runs the
///    conditional #482 `moveLatch` / `scheduleMoveSettle` pair
///    instead, and emits no `spaceChange`.
///
/// The spring and the crossing run MID-DRAG: the pointer is
/// inside the OS drag loop, so they assert no AX focus and
/// schedule no settle (a warp would rip the pointer out of the
/// drag); the crossed gesture's DROP schedules the #463 settle
/// instead (`handleDragEnd`). All four emit
/// `windowMovedToSpace`; all but the no-follow move emit
/// `spaceChange`. Placement can never
/// diverge: relocate and crossing share `insertDropped`; spring
/// and moveWindow share `addFocusedToSpace` (which insertDropped
/// also routes through for track / empty destinations).
extension KiwiCore {
    /// The window the live drop-zone highlight should mark, or nil
    /// to suppress it. Suppresses over a **cross-display track**
    /// destination: a track space files an arriving window by its
    /// `new_window` rule, not the pointed slot, so highlighting that
    /// slot would promise a landing the drop won't honor (#492). A
    /// same-display drop (which swaps positionally) and a non-track
    /// destination (which inserts on the slot) keep their truthful
    /// highlight. `origin` is the dragged window's home space.
    func dropZoneTarget(
        _ target: WindowID?,
        from origin: Space
    ) -> WindowID? {
        guard let target,
            let sid = state.workspaces.space(of: target),
            sid != origin.id,
            state.workspaces[sid]?.mode == .track
        else { return target }
        return nil
    }

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
            // Same display resolution the live crossing uses
            // (#504) — injected, so drag tests can fake a
            // topology; wired to NSScreen in wireDragCrossing.
            let display = dragCrossing.displayAt(cocoaCursor),
            let destID = state.workspaces.activeSpace(on: display),
            destID != origin.id,
            state.workspaces[destID] != nil
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
        insertDropped(id, onto: target, into: destID)
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

    /// Files a dragged window into `destID` — the ONE placement
    /// choke point shared by the drop-commit relocate (#492) and
    /// the live crossing (#504), so the two paths can never land
    /// a window differently. Onto a member window in a geometric /
    /// array-order layout: the target's index (target and
    /// followers shift one). A track destination, or no / foreign
    /// target: `addFocusedToSpace`, the same seam a keyboard /
    /// Space-Bar move uses, so the `new_window` rule and track
    /// cap / spill live in one place.
    func insertDropped(
        _ id: WindowID,
        onto target: WindowID?,
        into destID: SpaceID
    ) {
        guard let dest = state.workspaces[destID] else { return }
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
    }
}
