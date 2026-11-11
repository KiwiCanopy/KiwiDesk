import Foundation

extension LaunchFollowIntent {
    /// A popup that opened while its app's launch follow was owed
    /// (#3189), and the Space it opened in: the App Rule skips a
    /// popup, so it opens where the user is, and the follow would
    /// leave it behind.
    struct Rider: Equatable {
        let window: WindowID
        let from: SpaceID
    }

    /// A follow to pay: the Space, and the riders its debt held.
    /// The unowed arm (#2478) has no debt, so it carries none.
    struct Claim: Equatable {
        let space: SpaceID
        var riders: [Rider] = []
    }
}
