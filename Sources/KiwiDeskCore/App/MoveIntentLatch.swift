import Foundation

/// Latch suppressing follow on focus re-reports for windows
/// moved without follow (`scheduleFocusFollow`, #22, #463, #482,
/// #483). Deliberately honor-except-follow, NOT a
/// revert-and-return sibling of `handleWindowFocused`'s distrust
/// ladder: a latched report may be a genuine click the latch
/// cannot tell from the echo, so focus, ring and emit are all
/// honored — only the space-follow is suppressed. Revert
/// semantics would eat a real click's focus, a worse residue.
@MainActor
final class MoveIntentLatch {
    /// Age window within which focus follow is suppressed:
    /// Electron/WebKit answer AX lazily (100–300 ms), so the echo
    /// can trail by several hundred ms; beyond ~1 s a report is a
    /// user action. Accepted trade: a genuine click on the moved
    /// window inside the window is not followed once
    /// (accepted-limitations row).
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
