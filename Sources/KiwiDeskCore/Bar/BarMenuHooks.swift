import Foundation

/// Where a bar menu's Settings row lands (#1518). Core names the
/// place; the GUI maps it to a destination and the row to reveal,
/// the way the search lands (#96, #277).
public enum SettingsLanding: Equatable, Sendable {
    /// KiwiShelf & Bars, on the KiwiShelf card.
    case shelf
    /// Looks & Animations.
    case looks
    /// Advanced Colors.
    case advancedColors
    /// Spaces, on this Space's card.
    case space(SpaceID)
}

/// What a bar menu asks of the GUI (#1518) — set at the GUI's
/// bootstrap, beside `uiBridge`.
public struct BarMenuHooks {
    /// Opens Settings on `landing`.
    public var openSettings: @MainActor (SettingsLanding) -> Void = {
        _ in
    }
    /// The Layout menu's Keep row: the status item's own save, so
    /// a failure is reported the one way it already is.
    public var keepLayout: @MainActor () -> Void = {}
    /// A menu wrote a setting into the live profile's file: an open
    /// Settings draft takes the same edit, so its next Save does not
    /// write the old value back (the #1720 shape).
    public var settingsWritten:
        @MainActor (@escaping (inout TilingSettings) -> Void) -> Void = {
            _ in
        }

    public init() {}
}

extension KiwiCore {
    /// The bar menus' GUI hooks (#1518).
    public var barMenuHooks: BarMenuHooks {
        get { shelves.contextMenus.hooks }
        set { shelves.contextMenus.hooks = newValue }
    }
}
