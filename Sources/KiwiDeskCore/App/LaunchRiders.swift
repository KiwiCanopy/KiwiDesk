import Foundation

/// The popups that opened while an app's launch follow was owed
/// (#3189): the App Rule skips a popup, so it opens where the user
/// is, and the follow would leave it behind. One app's at a time,
/// each with the Space it opened in; they end with the debt.
struct LaunchRiders {
    struct Rider: Equatable {
        let window: WindowID
        let from: SpaceID
    }

    private var bundleID: String?
    private var riders: [Rider] = []

    /// Notes a popup of `bundleID`; another app's riders give way.
    mutating func note(_ rider: Rider, of bundleID: String) {
        if self.bundleID != bundleID { riders = [] }
        self.bundleID = bundleID
        riders.removeAll { $0.window == rider.window }
        riders.append(rider)
    }

    /// Takes `bundleID`'s riders, once; any other app's are dropped.
    mutating func take(_ bundleID: String?) -> [Rider] {
        defer { clear() }
        return self.bundleID == bundleID ? riders : []
    }

    mutating func clear() {
        bundleID = nil
        riders = []
    }
}

extension LaunchFollowIntent {
    /// Notes `rider` while `bundleID`'s debt stands; owed nothing,
    /// the popup stays where it opened.
    func noteRider(
        _ rider: LaunchRiders.Rider,
        of bundleID: String,
        at now: Date
    ) {
        guard owed(at: now) == bundleID else { return }
        riders.note(rider, of: bundleID)
    }

    /// The riders of the follow being paid for `bundleID`.
    func takeRiders(of bundleID: String?) -> [LaunchRiders.Rider] {
        riders.take(bundleID)
    }
}
