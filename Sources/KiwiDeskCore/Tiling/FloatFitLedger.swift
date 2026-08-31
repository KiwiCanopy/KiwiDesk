import CoreGraphics

/// Tracks refused resize asks for floating windows outside layout loop
/// (`SizeBoundLearner`, `state-and-layout.md`, `layoutInput`, #677, #1091).
struct FloatFitLedger {
    private var refused: [WindowID: (asked: CGSize, seen: CGSize)] =
        [:]

    /// Checks if ask repeats an unanswered resize request for window (#1091).
    func repeatsRefusal(
        _ window: WindowID,
        asked: CGSize,
        seen: CGSize
    ) -> Bool {
        guard let entry = refused[window] else { return false }
        return entry.asked == asked && entry.seen == seen
    }

    /// Records an issued resize ask against reported frame.
    mutating func record(
        _ window: WindowID,
        asked: CGSize,
        seen: CGSize
    ) {
        refused[window] = (asked, seen)
    }

    /// Clears ledger entry for window.
    mutating func forget(_ window: WindowID) {
        refused[window] = nil
    }
}
