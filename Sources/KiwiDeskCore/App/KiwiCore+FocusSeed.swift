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
    /// steals no OS focus. The frontmost read is the one
    /// `trustedFrontmostTracked` copy (#1130).
    func seedStartupFocus() {
        seedStartupFocus(frontmost: trustedFrontmostTracked())
    }

    /// Testable core, the OS-frontmost managed window injected.
    ///
    /// The frontmost window seeds *unconditionally*: it is what
    /// the user is actually looking at, so it corrects both the
    /// wiped and the arbitrary-discovery focus (and is a no-op
    /// when a real focus event already landed on it). A member
    /// of the active space takes its `focused` slot; a managed
    /// window homed elsewhere — a sticky traveler rendered over
    /// the active space — folds into its HOME slot, exactly as
    /// `windowFocused` would, so `lastFocused` lets the anchor
    /// surface it (#416/#431). The fallback (first tiled member,
    /// else first window of an all-floating space) runs only
    /// when nothing is focused yet: it is a guess, and must
    /// never override a real restored or observed focus.
    func seedStartupFocus(frontmost: WindowID?) {
        guard let space = activeSpace else { return }
        if let frontmost {
            if space.windows.contains(frontmost) {
                state.workspaces.focus(frontmost, in: space.id)
                return
            }
            if let home = state.workspaces.space(of: frontmost) {
                state.workspaces.focus(frontmost, in: home)
            }
        }
        guard focusedWindowID == nil else { return }
        let candidate =
            state.localTiledMembers(of: space).first
            ?? space.windows.first
        guard let candidate else { return }
        state.workspaces.focus(candidate, in: space.id)
    }

    /// The OS-frontmost app's AX-focused window id — the one
    /// shared "trusted frontmost" chain (#442 review): frontmost
    /// app, distrusted while it shows an ignored panel (issue
    /// #21: AX then reports the app's stale *main* window as
    /// focused), then its AX-focused window resolved to an id.
    /// Callers add their own tail: the startup seed requires the
    /// id to be tracked; the startup landing falls back to the
    /// session's remembered space for a not-yet-tracked id.
    func trustedFrontmostFocusedWindowID() -> WindowID? {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            !FloatDetection.hasVisibleIgnoredPanel(
                pid: app.processIdentifier,
                bundleID: AppRef(app).bundleID,
                isAccessory: EventLoop.classifiesAsOverlay(
                    pid: app.processIdentifier,
                    activationPolicy: app.activationPolicy
                )
            ),
            let element = AXHelper.focusedWindow(
                pid: app.processIdentifier
            )
        else { return nil }
        return AXHelper.windowID(of: element)
    }
}
