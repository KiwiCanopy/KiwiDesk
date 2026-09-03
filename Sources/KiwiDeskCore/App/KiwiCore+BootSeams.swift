import AppKit
import Foundation

/// The machine seams `start()` arms, together (#801 split them
/// out of it).
///
/// Every one of them is nil or inert until here on purpose: a
/// unit test constructing a `KiwiCore` must not read the host's
/// frontmost app, move the developer's pointer or touch its real
/// windows (tests.md — a test reaches the machine only through a
/// seam it injects). They are armed in one place so a new one is
/// missing from a run of near-identical lines rather than from a
/// hundred-line boot function; `ClickProvenanceWiringTests` pins
/// the two that no behavior test can red on.
extension KiwiCore {
    func armMachineSeams() {
        // Arm the focused-command foreground guard (#292): from
        // now on, an implicit-focused command fails closed unless
        // the OS frontmost app is KiwiDesk's focused managed
        // window.
        frontmostPIDProvider = {
            NSWorkspace.shared.frontmostApplication?
                .processIdentifier
        }
        // The wake payment's fallback seed reads the one trusted
        // frontmost chain (#442/#1130).
        trustedFrontmostProvider = { [weak self] in
            self?.trustedFrontmostFocusedWindowID()
        }
        // Arm the raise-echo revert's click-provenance check
        // (#687): the press stamp below resolves which window
        // each click reached.
        stackingOrderProvider = {
            AXHelper.onScreenStackingOrder()
        }
        // Yields key focus to the desktop when a move empties the
        // focused display's space (#446) — Finder owns the
        // desktop, gated so it never teleports the user to
        // another Desktop.
        desktopFocusYield = { [weak self] in
            self?.yieldFocusToDesktop()
        }
        // The warp's machine tail (#186): target geometry is pure
        // (`MouseWarp.target`), the cursor read and the pointer
        // move are not.
        pointerWarp = { frame in
            guard
                let target = MouseWarp.target(
                    frame: frame,
                    cursor: CGEvent(source: nil)?.location
                )
            else { return }
            CGWarpMouseCursorPosition(target)
            // A programmatic warp decouples the hardware mouse
            // for the local-events suppression interval
            // (~250 ms) — a dead mouse right when "the next click
            // lands where the keyboard works" is the whole point.
            // Re-associate immediately so the pointer is live.
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        // A bare left click on another monitor's empty desktop
        // moves the focused display (#446). The press also stamps
        // the click discriminator for the cross-display sibling
        // distrust (#496) — in AX coordinates, the space window
        // frames live in.
        mouse.onLeftMouseDown = { [weak self] point in
            let axPoint = GeometryUtils.axPoint(point)
            // Resolve which window the press reached NOW, not
            // when a raise echo asks (#687): press time is when
            // the fact exists — `clickReachedWindow` carries the
            // argument.
            self?.lastLeftClick = (
                Date(),
                axPoint,
                self?.clickReachedWindow(at: axPoint)
            )
            self?.followDisplayUnderClick(at: point)
        }
        // Both memories from ONE reading (#888): the authority
        // the switch handler compares against, and the
        // per-display Spaces it diffs against. Seeding only the
        // first left the session's opening switch diffing against
        // an empty snapshot.
        //
        // Stamped (#1147): boot is where a Desktop that has
        // never met KiwiDesk gets its identity, so the first
        // binding resolve of the session already has one to file
        // under rather than a number a renumber can move.
        let desktops = stampedDesktopSnapshot()
        lastDesktop = desktops.authority
        desktopMemory.seed(desktops)
        // Cheap and off-main; kicked here so the first glyph bar
        // never renders an image-fallback frame.
        appFont.preload()
        borders.start()
        // The mark rides the ring's WindowServer bounds stream —
        // AX move echoes alone lag visibly during drags. The
        // reposition path is unguarded (WS bounds are the truth);
        // the reorder tee re-asserts stacking on a raise that
        // fires no AX focus event (a re-click on the focused
        // window); and the tracking predicate lets the mark's
        // AX-echo `follow` stand down while the WS stream owns
        // the frame.
        borders.onFrameReconciled = { [weak self] id, frame in
            self?.stickyMarks
                .reposition(id, windowFrame: frame)
        }
        borders.onWindowReordered = { [weak self] id in
            self?.stickyMarks.reassert(id)
        }
        stickyMarks.isWindowServerTracked = { [weak self] id in
            self?.borders.markUsesWindowServerTracking(id) ?? false
        }
    }
}
