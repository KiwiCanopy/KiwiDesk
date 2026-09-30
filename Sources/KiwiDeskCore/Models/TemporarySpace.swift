import Foundation

/// A temporary Space's lifetime state (#1790): made on the fly,
/// in no arrangement, dropped on a switch, deleted once emptied.
/// A stored cross-version shape — every session snapshot carries
/// it (`StateSnapshot.SpaceRecord.temporary`).
public struct TemporarySpace: Codable, Equatable, Sendable {
    /// Whether anything has been in it since it was made: the
    /// auto-delete fires only on the departure that empties an
    /// ARMED Space, so one made empty from the bar stays.
    public var armed: Bool

    public init(armed: Bool = false) {
        self.armed = armed
    }
}

/// Where `create_space` and `delete_space` act (#1790): the live
/// setup alone, or the live profile's file as well.
public enum SpaceScope: String, Sendable, CaseIterable {
    case session
    case profile
}
