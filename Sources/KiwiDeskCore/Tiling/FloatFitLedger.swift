import CoreGraphics

/// Tracks refused resize asks for floats, outside the layout
/// loop (deliberately NOT a `SizeBoundLearner` entry —
/// `state-and-layout.md`; #677, #1091). The evidence is a PAIR:
/// the size asked and the size the window still reported.
/// Anything that moves either half — the user resizing, the app
/// changing its mind, a bar edit — produces a different pair and
/// asks again, so nothing has to invalidate this explicitly.
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

    /// Records an issued resize ask against the reported frame —
    /// at the ASK, not on an observed refusal: the answer arrives
    /// asynchronously as an echo, and a complying window simply
    /// stops being oversized and never consults this again.
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
