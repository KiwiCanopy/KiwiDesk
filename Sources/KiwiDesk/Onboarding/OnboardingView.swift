import KiwiDeskCore
import SwiftUI

/// Root view for the first-launch onboarding tour (#828).
struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    @EnvironmentObject private var localization: LocalizationManager
    @Environment(\.colorScheme) var colorScheme

    static let size = CGSize(width: 560, height: 620)
    /// Padding on each side, horizontal then vertical.
    static let inset = CGSize(width: 30, height: 26)
    /// Room between the progress row and the page.
    static let spacing: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            progressRow
            switch model.step {
            case .grant:
                grant
            case .spaces:
                spaces
            case .looks:
                OnboardingLooksStep(model: model)
            case .bars:
                OnboardingBarsStep(model: model)
            case .keys:
                keys
            case .done:
                done
            }
        }
        .padding(.horizontal, Self.inset.width)
        .padding(.vertical, Self.inset.height)
        // Fixed window frame sized for all locales (#828,
        // `OnboardingBarsFitTests`).
        .frame(width: Self.size.width, height: Self.size.height)
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
