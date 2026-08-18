import CoreGraphics
import Foundation

/// The active-Desktop authority (#888): which Mission Control
/// desktop counts as "the" active one for Desktop→profile
/// bindings and the per-Desktop Space memory.
///
/// The definition: **the MAIN display's current Desktop**.
/// KiwiDesk resolves one active profile for the whole setup, so
/// one display has to hold the authority, and the main display
/// (the screen with the menu bar) is it — a secondary display's
/// swipe never changes this answer. With "Displays have separate
/// Spaces" off, or with a single display, the main display's
/// Desktop IS the global one, so the answer degenerates to
/// `activeSpaceNumber()` exactly.
extension NativeSpaces {
    /// UUID of the main display (the screen with the menu bar),
    /// or nil when `CGDisplayCreateUUIDFromDisplayID` is
    /// unavailable.
    public static func mainDisplayUUID() -> String? {
        #if DEBUG
            if let override = mainDisplayUUIDOverride {
                return override
            }
        #endif
        return displayUUID(for: DisplayID(CGMainDisplayID()))
    }

    /// Mission Control number of the active Desktop: the MAIN
    /// display's current Desktop (#888). Nil when that Desktop
    /// is a fullscreen/system space, or without SkyLight
    /// (callers treat nil as single-space, as with
    /// `activeSpaceNumber()`).
    ///
    /// Resolved from ONE `allSpaces()` snapshot — the
    /// per-display `isCurrent` flags — so the number and the
    /// topology it is counted in cannot disagree mid-read.
    /// When the main display cannot be found in that snapshot
    /// (no SkyLight, no display-UUID symbol, or macOS's shared
    /// mode, whose managed display carries a synthetic
    /// identifier), the global `activeSpaceNumber()` answers —
    /// the public-fallback ladder os-private-apis.md requires,
    /// and in shared mode the global number is exactly the main
    /// display's.
    public static func activeDesktopNumber() -> Int? {
        #if DEBUG
            if let override = activeDesktopNumberOverride {
                return override
            }
        #endif
        let spaces = allSpaces()
        guard let uuid = mainDisplayUUID(),
            let current = spaces.first(where: {
                $0.displayUUID == uuid && $0.isCurrent
            })
        else { return activeSpaceNumber() }
        return number(of: current.id, in: spaces)
    }
}
