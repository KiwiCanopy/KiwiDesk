import AppKit
import Foundation

/// Startup focus seeding (#442). A fresh boot leaves the focus
/// state useless in one of two ways: a session restore rebuilds
/// the spaces and wipes the discovery-time focus (both
/// `Space.focused` and the anchor derive nil), or — with no
/// session to restore — discovery order leaves focus on an
/// arbitrary last-scanned window whose pid rarely matches the
/// OS foreground. Either way every implicit-focused command
/// fails "no managed window is currently focused" until the
/// first real click. No AX focus event fires for the window
/// that is *already* frontmost at boot, so nothing heals this
/// without user input.
extension KiwiCore {
    /// Seeds internal focus state after the startup landing
    /// (session restore and the delayed startup sweep). State
    /// only — never raises or AX-focuses anything, so launch
    /// steals no OS focus.
    func seedStartupFocus() {
        seedStartupFocus(frontmost: frontmostManagedWindowID())
    }

    /// Testable core, the OS-frontmost managed window injected.
    ///
    /// The frontmost window — when it is a member of the active
    /// space — seeds *unconditionally*: it is what the user is
    /// actually looking at, so it corrects both the wiped and
    /// the arbitrary-discovery focus (and is a no-op when a
    /// real focus event already landed on it). The fallback
    /// (first tiled member, else first window of an all-floating
    /// space) runs only when nothing is focused yet: it is a
    /// guess, and must never override a real restored or
    /// observed focus.
    func seedStartupFocus(frontmost: WindowID?) {
        guard let space = activeSpace else { return }
        if let frontmost, space.windows.contains(frontmost) {
            state.workspaces.focus(frontmost, in: space.id)
            return
        }
        guard focusedWindowID == nil else { return }
        let candidate =
            state.localTiledMembers(of: space).first
            ?? space.windows.first
        guard let candidate else { return }
        state.workspaces.focus(candidate, in: space.id)
    }

    /// The OS-frontmost app's AX-focused window, resolved to a
    /// tracked id. Mirrors `activateSpaceOfFocusedWindow`'s
    /// distrust of apps currently showing an ignored panel
    /// (issue #21): while a quick-terminal-style panel is open,
    /// AX reports the app's main window as focused.
    private func frontmostManagedWindowID() -> WindowID? {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            !FloatDetection.hasVisibleIgnoredPanel(
                pid: app.processIdentifier,
                bundleID: AppRef(app).bundleID
            ),
            let element = AXHelper.focusedWindow(
                pid: app.processIdentifier
            ),
            let id = AXHelper.windowID(of: element),
            state.windows[id] != nil
        else { return nil }
        return id
    }
}
