import Foundation

extension KiwiCore {
    /// Fail-closed preflight for implicit-focused commands (#292).
    /// Returns a failed `CommandResponse` — and blocks the command
    /// before any state mutation — when the command acts on the
    /// focused window but the OS foreground is not that managed
    /// window. Returns `nil` (allow) otherwise.
    ///
    /// The guard is inert until `frontmostPIDProvider` is wired
    /// (`start()` installs it; unit tests leave it `nil`), so it
    /// never touches config setters, `focus_space`, spawns, profile
    /// ops, reads, or explicit-id App Bar actions — only the
    /// commands `FocusedCommandPolicy` classifies as focused.
    ///
    /// Foreground ownership requires ALL of:
    /// 1. `focusedWindow` (the focus ANCHOR, `focusedWindowID`, so a
    ///    frontmost tiled-sticky traveler is recognized, not the
    ///    stale local slot) resolves to a tracked window;
    /// 2. the OS frontmost app shares that window's pid;
    /// 3. the event loop still observes that pid;
    /// 4. no ignored panel is latched for that pid.
    ///
    /// Any nil/mismatch fails closed. A self-raise in flight is not
    /// a bypass: the command is allowed only once the OS frontmost
    /// pid actually matches, so an activation race rejects a
    /// shortcut rather than mutating a hidden window.
    func focusedCommandDenial(
        for command: String
    ) -> CommandResponse? {
        guard let frontmostPID = frontmostPIDProvider,
            FocusedCommandPolicy.isFocused(command)
        else { return nil }
        guard let focused = focusedWindow,
            let front = frontmostPID(),
            front == focused.pid,
            eventLoop.observes(pid: focused.pid),
            !ignoredPanelActive.contains(focused.pid)
        else {
            return .fail("no managed window is currently focused")
        }
        return nil
    }
}
