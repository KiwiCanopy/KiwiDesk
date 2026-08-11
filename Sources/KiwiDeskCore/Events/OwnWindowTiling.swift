import Foundation

/// The mark for the one own window that tiles (#678 item 18).
///
/// Own windows are discriminated per WINDOW, never per process:
/// the GUI stamps this identifier onto the Settings window
/// (`SettingsWindowController`), and
/// `EventLoop.shouldForceFloat` reads it back through the
/// `ownWindowIdentifier` seam. Settings persists beside the
/// user's work, so it tiles; a surface with a completion
/// condition is chrome and stays out of the tiler's domain (the
/// argument is in `docs/design-decisions.md`).
///
/// **This doc is where the own-window census lives** — the
/// other sites cite it rather than re-listing, since a new own
/// window falsifies every copy and reds none of them. As of
/// #678 Phase 5 the process builds three titled windows and
/// several panels:
///
/// - **Settings** — marked, tiles. The one exception.
/// - **The onboarding tour** and **the Config Issues window** —
///   titled, main-capable, unmarked, so they are tracked and
///   force-floated. Both end.
/// - **Every own `NSPanel`** — the ⌃⌥K shortcuts panel, the
///   menu-bar coach mark, the drag ghost and drop zones, the
///   border and sticky overlays — never reaches the float
///   question at all: `shouldIgnoreOwnWindow` drops anything
///   that cannot become main before tracking, which is also
///   what keeps the ⌃⌥K panel out of both bars.
///
/// A new own window is unmarked, and therefore chrome, by
/// DEFAULT — the failure direction that costs a stray float
/// rather than a stolen layout slot.
/// `OwnWindowTilingSeamTests`' allowed map is the one copy of
/// who may stamp the mark.
public enum OwnWindowTiling {
    public static let identifier = "kiwidesk.tiles"
}
