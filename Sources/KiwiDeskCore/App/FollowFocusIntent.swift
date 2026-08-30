import Foundation

/// Tracks deferred focus debt across Desktop switches (#1007,
/// `FollowFocusIntentTests`).
@MainActor
final class FollowFocusIntent {
    /// Maximum duration focus debt remains claimable (5.0s, #1007).
    static let drainWindow: TimeInterval = 5.0

    private var pending: (window: WindowID, at: Date)?

    /// Records that `id` was sent to a Desktop the user asked to follow onto.
    func record(_ id: WindowID, at now: Date = Date()) {
        pending = (id, now)
    }

    /// Claims owed focus if window is currently payable (#1007).
    func claim(
        at now: Date = Date(),
        if isPayable: (WindowID) -> Bool
    ) -> WindowID? {
        guard let pending else { return nil }
        guard
            now.timeIntervalSince(pending.at) < Self.drainWindow
        else {
            self.pending = nil
            return nil
        }
        guard isPayable(pending.window) else { return nil }
        self.pending = nil
        return pending.window
    }

    /// Updates tracked window ID across native tab switches (#308).
    func rekey(old: WindowID, new: WindowID) {
        guard let pending, pending.window == old else { return }
        self.pending = (new, pending.at)
    }
}
