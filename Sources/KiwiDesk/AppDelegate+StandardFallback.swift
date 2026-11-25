import AppKit
import KiwiDeskCore

extension AppDelegate {
    /// The Standard notice (#3646), shown once Core's screen-change
    /// handler has returned so the window never opens mid-change; it
    /// stands down while the tour owns the screen.
    func wireStandardFallbackNotice() {
        core.onStandardFallback = { [weak self] fallback in
            Task { @MainActor [weak self] in
                StandardFallbackNotice.present(
                    fallback,
                    tourShowing:
                        self?.onboardingWindow?.isVisible == true
                )
            }
        }
    }
}
