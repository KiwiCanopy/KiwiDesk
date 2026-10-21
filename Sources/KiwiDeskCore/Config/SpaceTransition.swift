import Foundation

/// How an explicit Space switch shows itself (`space.transition`,
/// #2524).
public enum SpaceTransition: String, Codable, CaseIterable, Sendable {
    /// The #1956 plate slide; Reduce Motion shows the plate instead.
    case slide
    /// At once, and #2142's plate names the Space for a moment.
    case show
    /// At once, with no cue.
    case none
}
