import SwiftUI

/// Live-apply feedback auto-fade for KeyRecorderField (#123).
extension KeyRecorderField {
    /// Schedules timed fade of live-apply feedback, respecting
    /// Reduce Motion (#989).
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
