import SwiftUI

/// Live-apply feedback auto-fade for KeyRecorderField (#123).
extension KeyRecorderField {
    /// Schedules timed fade of live-apply feedback. One writer,
    /// latest wins: the equality check keeps an older timer from
    /// clearing a newer caption early. Reduce Motion drops only
    /// the motion (#989) — the caption still appears and leaves,
    /// and here the caption IS the affordance.
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
