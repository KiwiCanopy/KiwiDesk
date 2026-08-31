import Foundation

/// Latch suppressing follow on focus re-reports for windows moved
/// without follow
/// (`scheduleFocusFollow`, `handleWindowFocused`, #22, #463, #482, #483).
@MainActor
final class MoveIntentLatch {
    /// Age window within which focus follow is suppressed.
    static let window: TimeInterval = 1.0

    private var stamps: [WindowID: Date] = [:]

    /// Records no-follow move timestamp for window, pruning expired entries.
    func stamp(_ id: WindowID, at now: Date = Date()) {
        stamps = stamps.filter {
            now.timeIntervalSince($0.value) < Self.window
        }
        stamps[id] = now
    }

    /// Tests if window's focus report is currently latched against follow.
    func isLatched(_ id: WindowID, at now: Date = Date()) -> Bool {
        guard let stamp = stamps[id] else { return false }
        return now.timeIntervalSince(stamp) < Self.window
    }

    /// Transfers latch stamp on native-tab re-key (`.windowRekeyed`, #308).
    func rekey(old: WindowID, new: WindowID) {
        guard let stamp = stamps.removeValue(forKey: old) else {
            return
        }
        stamps[new] = stamp
    }
}
