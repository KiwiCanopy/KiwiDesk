import Foundation
import KiwiDeskCore

/// The appearance picker's read/write path (#678 item 8).
///
/// Sits in the "applies immediately" group with the language
/// pick, and for the same reason: it is not part of a profile and
/// ignores the footer's Save entirely. Turn 14b makes that
/// grouping the design rather than a detail — a row that Revert
/// appears to undo and does not is the fourth finding from the
/// 6b audit, and the heading is what stops it.
///
/// `@Published` is what re-renders the shell: the pick is read
/// once at `SettingsModel` init and then lives here, so writing
/// it both persists and repaints in one step.
extension SettingsModel {
    /// Persists the pick and repaints the window. `.system` hands
    /// the decision back to macOS and leaves no key behind.
    func setAppearance(_ choice: AppearanceChoice) {
        AppearancePreference.write(choice)
        appearance = choice
        choice.apply()
    }
}
