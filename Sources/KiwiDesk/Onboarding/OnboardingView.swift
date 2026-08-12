import KiwiDeskCore
import SwiftUI

/// The first-launch tour: permission, the spaces it chose, the
/// keys it bound, and the way out.
///
/// The state it draws is `OnboardingModel`, one file over — split
/// out when the progress row landed (#828) so neither file
/// approaches the §2.1 ceiling.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    @EnvironmentObject private var localization: LocalizationManager
    /// Read here rather than in the grant extension: `@Environment`
    /// is a stored property and an extension cannot hold one.
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            progressRow
            switch model.step {
            case .grant:
                grant
            case .spaces:
                spaces
            case .keys:
                keys
            case .separateSpaces:
                separateSpaces
            case .done:
                done
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 26)
        // One frame for every step, since the window is sized from
        // `fittingSize` once at creation and never resized on a
        // step change — a per-step frame would clip whichever step
        // is larger than the one that opened.
        //
        // 560×620 (#828). The old 520×430 truncated the grant
        // step's body in German and the closing card's menu-bar
        // line in English — a fixed frame means every locale has
        // to fit the tightest one, so the frame is what gives.
        //
        // The prototype's 700 was tried first and left every step
        // but one standing in empty space (owner, on device,
        // 2026-08-12). 620 is sized to the tallest step that
        // CANNOT scroll; the spaces step, the one that grows with
        // the user's monitors, has a scrolling list instead —
        // which is why it is not what sets this number.
        .frame(width: 560, height: 620)
        // The tour's own ground and ink, not the system's (#828).
        // The window is `.titled` with a transparent titlebar over
        // `.fullSizeContentView`, so this paints the title strip
        // too — deliberately, and with no `NSColor` window surface
        // behind it, the wiring lens having retired the two
        // Settings had.
        .background(SettingsTheme.page)
        .foregroundStyle(SettingsTheme.ink)
        // The tour's accent, set ONCE at the root exactly as
        // `SettingsView` does — the first window a user sees is
        // the last place the app should be wearing the system
        // tint, and the spaces step already draws its schematics
        // in kiwi green.
        .tint(SettingsTheme.accent)
    }

    /// At the TOP of the content column, above the heading, where
    /// the prototype puts it (#828) — a reader answers "how long
    /// is this?" before reading the screen, not after.
    ///
    /// One draw site for every step, `.grant` and `.done`
    /// included: the grant screen is where the question is worth
    /// the most, and a row that vanished on the last screen would
    /// disappear exactly where it says "that was all".
    ///
    /// Drawn from the model's plan, never from `Step.allCases` —
    /// see `OnboardingProgressRow`, which carries why that
    /// distinction is the whole design. A plan of one is no
    /// progress to report, which is arithmetic on the list rather
    /// than a policy about steps.
    @ViewBuilder private var progressRow: some View {
        if model.plannedSteps.count > 1,
            let index = model.progressIndex
        {
            OnboardingProgressRow(
                steps: model.plannedSteps,
                index: index
            )
        }
    }
}
