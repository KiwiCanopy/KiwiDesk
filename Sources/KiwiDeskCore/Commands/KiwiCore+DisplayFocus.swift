import AppKit
import Foundation

/// OS-level "focused display" enforcement (#446).
///
/// KiwiDesk's state already tracks a per-display active space
/// (`WorkspaceManager.activeSpace(on:)`), but nothing moved the
/// *focused* display when the user clicked an empty desktop on
/// another monitor — only a window-focus event did. So a new
/// window, a global sticky, and every "current space" command
/// stayed on the previous monitor until a window there was
/// clicked. This bridges the gap with a single cheap check per
/// click (see `MouseTracker.onLeftMouseDown`).
extension KiwiCore {
    /// Moves the focused display to the monitor under a bare
    /// left click, so `activeSpace` follows the cursor across
    /// monitors even when the click lands on empty desktop.
    ///
    /// `cocoaPoint` is the press location in Cocoa screen
    /// coordinates (the space `NSScreen.frame`/`visibleFrame`
    /// live in). A no-op on a single monitor, and whenever the
    /// clicked display is already the focused one.
    func followDisplayUnderClick(at cocoaPoint: CGPoint) {
        // A native desktop (Mission Control) transition re-reports
        // clicks against windows being re-tracked; don't flip the
        // focused display mid-restore (cf. scheduleFocusFollow).
        guard
            Date().timeIntervalSince(lastNativeSwitch)
                > NativeSwitch.settle
        else { return }
        // Only a click inside a screen's VISIBLE frame re-homes:
        // that area excludes the menu bar and Dock, so clicking
        // either never moves the focused display. KiwiDesk's own
        // bar overlays are exempt for free — a global monitor
        // never sees events routed to our own windows.
        guard
            let screen = NSScreen.screens.first(where: {
                $0.visibleFrame.contains(cocoaPoint)
            }),
            let display = screen.kiwiDisplay?.id
        else { return }
        let focusedDisplay = state.workspaces.activeSpace.flatMap {
            state.workspaces.display(of: $0)
        }
        guard display != focusedDisplay else { return }
        // Move focus to that display's shown space. Nothing to do
        // if the display has no assigned space, or its space is
        // already the active one (single-display collapse).
        guard
            let target = state.workspaces.activeSpace(on: display),
            target != state.workspaces.activeSpace
        else { return }
        // A bare desktop click deliberately leaves key focus on the
        // desktop, so no window is raised — forcing one forward
        // would fight it. This also fires on a cross-display
        // *window* click, redundantly with the AX focus-follow
        // path; the switch is idempotent (`target != activeSpace`
        // guards the repeat) so the overlap is harmless.
        applyFocusedSpaceSwitch(to: target)
    }

    /// Commits a focused-display / space switch to `space`: makes
    /// it the active space, force-retiles honouring the
    /// space-change animation (§5: an explicit switch forces past
    /// the "already there" tolerance check), and tells the bars.
    /// The shared tail of the empty-desktop display follow (#446)
    /// and the AX focus-follow (`scheduleFocusFollow`, #22) — each
    /// caller adds its own raise / warp / settle afterwards.
    func applyFocusedSpaceSwitch(to space: SpaceID) {
        state.workspaces.activate(space)
        retile(
            animated: tiler.settings.animations.onSpaceChange,
            force: true
        )
        emitSpaceChange()
    }

    /// Hands key focus to the desktop when a move empties the
    /// focused display's space (#446). macOS exposes no "focus the
    /// empty desktop" API, so we activate Finder (the desktop's
    /// owner) — but only when doing so cannot teleport the user to
    /// another Space (option 3, per ui-designer):
    ///   • Finder has no document windows anywhere → clean activate,
    ///     the desktop simply becomes frontmost.
    ///   • Finder has a window on a currently-visible space (any
    ///     display) → activate surfaces it on-screen, no switch.
    ///   • Finder's windows live only on non-visible spaces →
    ///     SKIP. Activating would jump Spaces (the "switch to a
    ///     Space with open windows" setting); leaving focus to
    ///     swallow keystrokes matches stock macOS's "last window
    ///     closed, no key window" state and is recoverable with a
    ///     click. This is the installed `desktopFocusYield`.
    /// Finder whose only windows are *minimized* also skips (it is
    /// off-screen, indistinguishable from other-space via the
    /// WindowServer) — an over-conservative but safe missed
    /// activation, not a teleport.
    func yieldFocusToDesktop() {
        guard
            let finder = NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.finder"
            ).first
        else { return }
        let pid = finder.processIdentifier
        let anyWindows = AXHelper.normalWindowCount(
            pid: pid,
            onScreenOnly: false
        )
        // Only pay the second WindowServer query when there is
        // something that could teleport.
        let onScreen =
            anyWindows == 0
            ? 0
            : AXHelper.normalWindowCount(
                pid: pid,
                onScreenOnly: true
            )
        guard anyWindows == 0 || onScreen > 0 else { return }
        finder.activate()
    }
}
