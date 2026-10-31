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
/// hundred-line boot function; `ClickProvenanceWiringTests` and
/// `OwnPressProvenanceSeamTests` pin the ones no behavior test
/// can red on.
extension KiwiCore {
    func armMachineSeams() {
        // Arm the focused-command foreground guard (#292): from
        // now on, an implicit-focused command fails closed unless
        // the OS frontmost app is KiwiDesk's focused managed
        // window.
        let frontmost: @MainActor () -> pid_t? = { [weak self] in
            self?.eventLoop.frontmostProcess()
        }
        frontmostPIDProvider = frontmost
        // The focus-report gate reads the same chain (#1322).
        eventLoop.frontmostPID = frontmost
        // The launch follow's press read (#1599).
        launchFollow.pressAge = { KiwiCore.secondsSinceUserPress() }
        // The unowed arm's process age (#2478).
        launchFollow.processAge = { [weak self] pid in
            self.flatMap {
                ProcessIdentity.startAge(of: pid, now: $0.wallClock())
            }
        }
        launchFollow.watchedFor = { [weak self] in
            self?.boot.began.map {
                TimeInterval($0.duration(to: .now) / .milliseconds(1))
                    / 1_000
            }
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
        mouse.onLeftMouseDown = { [weak self] point, origin in
            self?.stampLeftClick(at: GeometryUtils.axPoint(point))
            // A click on a window a lens holds clears it (#2103).
            self?.visionPressed()
            // Neither arm hears a press on a bar or the peek, so
            // every press it does hear is a click outside the peek
            // (#1946).
            self?.shelves.peek.dismiss()
            // The display follow stands down for our own
            // window's press: its bar-overlay exemption is the
            // global monitor's blindness (#446, #1281).
            if origin == .otherApp {
                self?.followDisplayUnderClick(at: point)
            }
        }
        // Hover focus (#1869): the rest's monitor runs only while
        // the setting is on.
        mouse.rest.onRest = { [weak self] point, armed in
            self?.focusUnderRestingPointer(at: point, armedFocus: armed)
        }
        mouse.rest.noteArm = { [weak self] in self?.focusedWindowID }
        mouse.rest.windowsAt = { [weak self] point in
            self?.trackedWindows(at: point) ?? []
        }
        tiler.onMouseSettings = { [weak self] settings in
            self?.mouse.rest.apply(settings)
        }
        mouse.rest.apply(tiler.settings.mouse)
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
        lastDesktop = desktops.mainCurrentKey
        desktopMemory.lastDesktopSpace = desktops.mainCurrentSpace
        desktopMemory.seed(desktops)
        // Cheap and off-main; kicked here so the first glyph bar
        // never renders an image-fallback frame.
        appFont.preload()
        borders.start()
        windowServer.start()
    }
}
