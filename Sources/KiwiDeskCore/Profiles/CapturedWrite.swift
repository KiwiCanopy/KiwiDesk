import Foundation

/// What a profile write from outside Settings wrote (#1179,
/// #1790): the draft's saved baseline follows exactly that.
public enum CapturedWrite: Sendable, Equatable {
    /// Keep: the modes of the profile's own Spaces.
    case layouts
    /// `save_profile`: the whole live setup — which Spaces exist,
    /// their order, pins and modes.
    case wholeLive
}
