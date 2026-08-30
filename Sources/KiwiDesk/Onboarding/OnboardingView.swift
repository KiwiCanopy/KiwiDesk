import KiwiDeskCore
import SwiftUI

/// Root view for the first-launch onboarding tour (#828).
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    @EnvironmentObject private var localization: LocalizationManager
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
            case .done:
                done
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 26)
        // Fixed 560×620 window frame sized for all locales (#828).
        .frame(width: 560, height: 620)
        .background(SettingsTheme.page)
        .foregroundStyle(SettingsTheme.ink)
        .tint(SettingsTheme.accent)
    }

    /// Top-aligned progress indicator for multi-step tour presentations
    /// (#828).
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
