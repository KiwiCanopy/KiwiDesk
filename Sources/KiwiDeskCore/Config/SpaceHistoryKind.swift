import Foundation

/// Which history `focus_space_back` and `focus_space_forward`
/// walk (#1655, `space_history`): each screen's own, or one
/// across every screen. With one screen the two are the same.
public enum SpaceHistoryKind: String, CaseIterable, Codable, Sendable {
    case perScreen = "per_screen"
    case allScreens = "all_screens"

    /// What a fresh install and an absent key take.
    public static let defaultKind: SpaceHistoryKind = .perScreen

    /// Whether the choice can change anything for a profile saved
    /// for `screens` screens: with one screen there is one history
    /// either way, which Settings states rather than offers. A
    /// dormant profile's count is still its count; 0 is unknown
    /// and stays offered.
    public static func choiceMatters(screens: Int) -> Bool {
        screens != 1
    }
}
