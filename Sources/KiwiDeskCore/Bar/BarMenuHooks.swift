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
    /// App Rules, on this app's row, by its lower-cased bundle id.
    case appRule(String)
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
    /// A Space chip's Delete of a profile Space (#1790): the GUI
    /// asks, and runs `confirmed` only on a yes. Core names the
    /// Space and the profile; the GUI words the question.
    public var confirmSpaceDelete:
        @MainActor (SpaceDeleteQuestion, @escaping @MainActor () -> Void)
            -> Void = { _, _ in }

    public init() {}
}

/// What a profile Space's Delete asks (#1790): whether to remove
/// `space` from `profile`'s file as well.
public struct SpaceDeleteQuestion: Equatable, Sendable {
    public let space: SpaceID
    public let profile: String
    /// Whether the Space carries a pin, a role or per-Space
    /// settings the delete also removes — Settings' own delete
    /// says so in that case.
    public let carriesOverrides: Bool
}

extension KiwiCore {
    /// The bar menus' GUI hooks (#1518).
    public var barMenuHooks: BarMenuHooks {
        get { shelves.contextMenus.hooks }
        set { shelves.contextMenus.hooks = newValue }
    }
}
