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
        state.workspaces.activate(target)
        // A focused-display move is a space switch: force past the
        // tolerance check, honour the space-change animation, and
        // tell the bars where we landed. No window is raised — a
        // bare desktop click deliberately leaves key focus on the
        // desktop, and forcing a window forward would fight it.
        retile(
            animated: tiler.settings.animations.onSpaceChange,
            force: true
        )
        emitSpaceChange()
    }
}
