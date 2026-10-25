import Foundation

/// What `focus <direction>` does at the last window that way
/// (#2493, `focus_wrap`), in every layout: stop, wrap within the
/// screen, or continue onto the neighbouring screen. With one
/// screen All screens is This screen. The Space step
/// (`KiwiCore.stepSpace`) reads it `withinScreen` (#2592).
public enum FocusWrap: String, CaseIterable, Codable, Sendable {
    case off
    case thisScreen = "this_screen"
    case allScreens = "all_screens"

    /// What a fresh install and an absent key take.
    public static let defaultMode: FocusWrap = .allScreens

    /// The mode for a step that never crosses screens — the scroll
    /// gesture's, which acts on the Space under the pointer, and the
    /// Space step's, which goes round one screen's Spaces.
    public var withinScreen: FocusWrap {
        self == .allScreens ? .thisScreen : self
    }

    /// A profile's sparse override for `value` over `base`: nil
    /// where it follows the base.
    public static func sparse(
        _ value: FocusWrap,
        over base: FocusWrap
    ) -> FocusWrap? {
        value == base ? nil : value
    }
}
