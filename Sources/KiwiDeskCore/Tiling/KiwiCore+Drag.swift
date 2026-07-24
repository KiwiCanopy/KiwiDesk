import AppKit
import CoreGraphics
import Foundation

/// Drop resolution for user window drags and resizes.
extension KiwiCore {
    /// Connects the drag coordinator's callbacks (once, from
    /// init).
    func wireDrag() {
        drag.isAnimating = { [weak self] id in
            guard let self else { return false }
            // Covers in-flight animations AND the trailing AX
            // echoes of frames we already applied: those
            // arrive after the animation settles and must not
            // read as user drags.
            return self.tiler.animation.isAnimating(window: id)
                || self.tiler.didRecentlySetFrame(id)
        }
        drag.onDragMove = { [weak self] id, start, frame in
            self?.handleDragMove(id, start: start, frame: frame)
        }
        drag.onDragEnd = { [weak self] id, start, frame in
            self?.handleDragEnd(id, start: start, frame: frame)
        }
        drag.isMousePressed = {
            NSEvent.pressedMouseButtons & 1 == 1
        }
        drag.cursorLocation = { NSEvent.mouseLocation }
        wireSpaceBarDrop()
        wireDragCrossing()
    }

    /// Drop over another window's layout slot: the two windows
    /// swap positions and everything readjusts. Drop anywhere
    /// else: the window snaps back to its own slot. A drop
    /// that changed the window's SIZE during the gesture is a
    /// resize gesture and adjusts the layout instead (see
    /// handleResizeEnd). Move vs resize is judged against the
    /// gesture's start frame, never the slot: a window that
    /// can't match its slot's size (min sizes, character
    /// grids — every overflow-cascade window whose app can't
    /// shrink that far) differs from it permanently, and slot
    /// comparison would turn every plain move into a resize.
    /// The window's true frame at drop time. The last AX event of
    /// a fast drag lags the real drop, so read it fresh from the
    /// element; fall back to the reported frame when the element is
    /// gone or reads empty.
    private func liveDropFrame(
        _ id: WindowID,
        fallback: CGRect
    ) -> CGRect {
        guard let element = eventLoop.element(for: id)
        else { return fallback }
        let live = AXHelper.frame(of: element)
        return live == .zero ? fallback : live
    }

    func handleDragEnd(
        _ id: WindowID,
        start: CGRect,
        frame: CGRect
    ) {
        tiler.dragExemptWindow = nil
        // Whether this gesture live-crossed displays (#504);
        // ends the crossing bookkeeping either way. A crossed
        // gesture is a MOVE for the resize gate below.
        let crossedDisplays = dragCrossing.endGesture(id)
        // For the crossed drop's #463 settle below — captured
        // before the retile/focus can change it, mirroring the
        // drop-commit relocate.
        let priorFrontmost =
            crossedDisplays ? frontmostPIDProvider?() : nil
        dragOverlay.hideAll()
        spaceBars.endDragAutoScroll()
        defer { scheduleBorderDropReconcile() }
        // Space Bar drop resolves first (#372). A fast drop onto a
        // different space's item relocates the window (stay put).
        // A drop after the space sprang needs no move here — the
        // window was already eager-moved into the now-active target
        // at spring time — so it falls through to the ordinary in-
        // space drop, which places it at the cursor's slot. Own-
        // space / off-bar also fall through unchanged.
        switch spaceBarDrop.ended(id, cursor: drag.cursorLocation())
        {
        case .relocate(let target):
            moveWindow(id, to: target, follow: false)
            return
        case .placeInSprung, .none:
            break
        }
        // A floating window is excluded from the layout swap/resize
        // logic below, but a drop that leaves it under a top app bar
        // hides its title bar and makes it ungrabbable — clamp it
        // back below the strip (#242).
        if state.windows[id]?.isFloating == true {
            let frame = liveDropFrame(id, fallback: frame)
            let clamped = floatFrameClampedClearOfBars(
                id,
                frame: frame
            )
            if clamped != frame {
                tiler.applyFrame(
                    id,
                    from: frame,
                    to: clamped,
                    animated: false
                )
            }
            return
        }
        guard let space = activeSpace,
            space.mode != .floating,
            state.windows[id]?.isFloating == false
        else { return }
        // A tiled-sticky traveler (#414 v2) is an on-screen
        // tile with no local slot: its reorder here is a v2
        // non-goal, but the gesture physically moved the
        // window and `.windowMoved` never retiles — a bare
        // return would strand it at the drop frame. Snap it
        // back to its injected slot instead.
        guard space.windows.contains(id) else {
            retile()
            // The tile just snapped back to its injected slot —
            // surface WHERE it actually belongs (#421).
            flashStickyHomeSpace(id)
            return
        }

        let frame = liveDropFrame(id, fallback: frame)
        let slots = tiler.calculatedFrames(state: state)
        // Resolve the swap target from the cursor, exactly as the
        // live preview did (#492), so the drop can never disagree
        // with the drop-zone the user saw. AX coords: flip the
        // Cocoa mouse location.
        let target = DragTarget.swapTarget(
            of: id,
            at: GeometryUtils.axPoint(drag.cursorLocation()),
            slots: slots
        )
        // A drop whose cursor ends on ANOTHER display moves the
        // window there — resolved BEFORE the resize gate below,
        // because dragging a big window onto a smaller display
        // makes macOS clamp its size, which `MouseResize.isResize`
        // would else read as a resize and snap it back (#492): a
        // gesture ending on another display is always a move, never
        // a resize. Same-display drops fall through (relocate
        // returns false when the destination is the origin space).
        if relocateAcrossDisplay(id, onto: target, from: space) {
            return
        }
        // A gesture that live-crossed displays (#504) skips the
        // resize interpretation: macOS clamps a big window's size
        // as it lands on a smaller display, which `isResize`
        // would read as a resize and mangle the destination's
        // ratios — the live twin of the relocate-before-resize
        // ordering above (#492).
        if slots[id] != nil,
            !crossedDisplays,
            MouseResize.isResize(from: start, to: frame)
        {
            // Only edges shared with a neighbor trade space;
            // pulling an outer (screen-side) edge snaps back
            // instead of growing windows on the far side.
            // All deltas are measured from the start frame
            // (where the window really was), not the slot.
            let effective =
                MouseResize.keepingInnerEdgeChanges(
                    slot: start,
                    frame: frame,
                    neighbors:
                        slots
                        .filter { $0.key != id }
                        .map(\.value)
                )
            if MouseResize.isResize(
                from: start,
                to: effective
            ) {
                handleResizeEnd(
                    id,
                    slot: start,
                    frame: effective,
                    in: space
                )
            } else {
                retile()
                focusWindow(id, warp: false)
            }
            return
        }
        // A tiled-sticky traveler is injected into this space's
        // layout but is not a member of it (#414 v2): dropping
        // another window onto it is refused by `Space.swap`'s
        // membership guard and would silently no-op. Share the one
        // refusal predicate + pill with the keyboard swap sites
        // (#435), then snap the dragged window back — a no-target
        // drop — and focus it. (`id` is a local member here: a
        // dragged traveler already returned early above.)
        if let target, refuseSwapOntoTraveler(target, in: space) {
            retile()
            focusWindow(id, warp: false)
            return
        }

        var crossedZones = false
        if let target {
            crossedZones = crossesStackBoundary(
                id,
                target,
                in: space
            )
            state.workspaces.withSpace(space.id) {
                $0.swap(id, target)
            }
        }
        // Applies the swap — honoring `on_window_swap`, like the
        // keyboard swap — or, without a target, snaps/animates the
        // dragged window back into its slot (a relayout).
        retile(
            animated: target != nil
                ? tiler.settings.animations.onWindowSwap : nil
        )
        // The dropped window has the user's attention: make
        // it the focused one, in state and for real. No warp:
        // this focus is mouse-made (#186), and a no-target
        // drop snaps the window back to a slot the pointer
        // may sit outside of.
        focusWindow(id, warp: false)
        // A live-crossed gesture activated the destination at
        // crossing time with NO settle (mid-drag, the spring
        // model); its drop is where the #463 re-assert belongs —
        // parity with the drop-commit relocate's obligation.
        if crossedDisplays {
            scheduleSpaceSettle(
                space.id,
                priorFrontmost: priorFrontmost
            )
        }
        if crossedZones {
            scheduleZOrderRestore()
        }
        // A drop that reorders an overflowing track scrambles its
        // pile just like a keyboard track.swap (#193); crossedZones
        // is stack-only, so the two are mutually exclusive.
        scheduleTrackZOrderRestoreIfOverflowing()
    }
}
