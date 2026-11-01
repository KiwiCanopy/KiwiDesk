import Foundation

/// Where a bar menu's Settings row lands (#1518). Core names the
/// place; the GUI maps it to a destination and the row to reveal,
/// the way the search lands (#96, #277).
public enum SettingsLanding: Equatable, Sendable {
    /// KiwiShelf & Bars, on the KiwiShelf card.
    case shelf
    /// Looks & Animations.
    case looks
    /// Looks & Animations, with its Colors & glass section open
    /// (#2389).
    case colorsAndGlass
    /// Spaces, on this Space's card.
    case space(SpaceID)
    /// App Rules, on this app's row, by its lower-cased bundle id.
    case appRule(String)
    /// Layout Defaults, on this layout's tab (#2229).
    case layoutDefaults(LayoutMode)
    /// Profiles (#2309).
    case profiles
    /// KiwiVision (#2309).
    case kiwiVision
    /// KiwiVision with its add-lens popover open (#2359 ruling 4).
    case newLens
}

/// What a bar menu, or a Core pill naming a key, asks of the GUI
/// (#1518, #2612) — set at the GUI's
/// bootstrap, beside `uiBridge`. KiwiHub's View side (#2229, #2309)
/// is a GUI caller of the same doors, so a Settings landing has
/// one route.
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
    /// The chord of `bundleID`'s Pocket key row (#2612 ▸ 1): Core
    /// names the app, the GUI renders the key, drawn and spoken.
    public var pocketKeyChord: @MainActor (String) -> RenderedChord? = {
        _ in nil
    }

    public init() {}
}

/// A chord as the GUI draws it and as VoiceOver says it (#2601).
public struct RenderedChord: Equatable, Sendable {
    public let drawn: String
    public let spoken: String

    public init(drawn: String, spoken: String) {
        self.drawn = drawn
        self.spoken = spoken
    }
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
