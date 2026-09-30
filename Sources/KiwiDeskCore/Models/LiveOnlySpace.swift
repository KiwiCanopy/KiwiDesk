import Foundation

/// A live Space the profile does not hold (#1790): a temporary one,
/// or a held one (#1507). Settings ▸ Spaces draws it view-only
/// after the profile's own rows; Core names it, the GUI words it.
public struct LiveOnlySpace: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case temporary
        /// Held from the screen of that name, for the saved profile
        /// named — nil where a Standard or no profile was live.
        case held(screen: String, profile: String?)
    }

    public let id: SpaceID
    public let kind: Kind
    public let mode: LayoutMode
    /// The identifier icon it wears, if any.
    public let icon: String?
    /// A temporary Space's add button can write now: a profile
    /// file is live. Always false for a held Space.
    public let canAdd: Bool

    public var isTemporary: Bool { kind == .temporary }
}
