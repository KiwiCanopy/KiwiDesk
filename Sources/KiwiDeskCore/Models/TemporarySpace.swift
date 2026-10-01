import Foundation

/// Where `create_space` and `delete_space` act (#1790): the live
/// setup alone, or the live profile's file as well.
public enum SpaceScope: String, Sendable, CaseIterable {
    case session
    case profile
}
