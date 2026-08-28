import SwiftUI

/// The live-apply caption's own fade (#123), split from
/// `KeyRecorderField` at AGENTS.md §2.1's line ceiling — the
/// same reason the conflict popover has its own file.
extension KeyRecorderField {
    /// Clears the caption ~1.5 s after it appeared.
    ///
    /// One writer, latest wins: a newer recording sets a new
    /// feedback and starts its own timer, and the equality
    /// check is what keeps the older timer from clearing it
    /// early.
    ///
    /// **The fade is gated on Reduce Motion (#989).** With it
    /// on the caption still appears and still leaves — the
    /// house split drops the motion, never the affordance, and
    /// here the caption IS the affordance: nothing else says
    /// the binding applied live.
    func scheduleFeedbackFade(_ feedback: LiveApplyFeedback) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard liveFeedback == feedback else { return }
            withAnimation(reduceMotion ? nil : .default) {
                liveFeedback = nil
            }
        }
    }
}
