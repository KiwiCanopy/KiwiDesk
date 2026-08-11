import Foundation

/// The mark for the one own window that tiles (#678 item 18).
///
/// Own windows are discriminated per WINDOW, never per process:
/// the GUI stamps this identifier onto the Settings window
/// (`SettingsWindowController`), and
/// `EventLoop.shouldForceFloat` reads it back through the
/// AX-id → `NSWindow` mapping. The own windows that deliberately
/// do NOT carry it, so they stay force-floated chrome: the
/// onboarding tour and the Config Issues window. Each of them
/// ends, and a surface with a completion condition is outside
/// the tiler's domain — Settings persists beside the user's
/// work, so it tiles (the argument is in
/// `docs/design-decisions.md`). Own panels — the ⌃⌥K shortcuts
/// panel, the menu-bar coach mark — never reach the float
/// question at all: `shouldIgnoreOwnWindow` drops them before
/// tracking, which is also what keeps the panel out of both
/// bars.
///
/// `OwnWindowTilingSeamTests`' allowed map is the one copy of
/// who may stamp it.
public enum OwnWindowTiling {
    public static let identifier = "kiwidesk.tiles"
}
