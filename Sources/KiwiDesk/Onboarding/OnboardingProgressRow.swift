import KiwiDeskCore
import SwiftUI

/// Onboarding tour progress row displaying pips for planned steps
/// (#828, OnboardingProgressTests).
struct OnboardingProgressRow: View {
    let steps: [OnboardingModel.Step]
    let index: Int
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private let pipWidth: CGFloat = 18
    private let pipHeight: CGFloat = 5

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(steps.enumerated()), id: \.offset) {
                position,
                _ in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        position <= index
                            ? SettingsTheme.accent
                            : SettingsTheme.hairline
                    )
                    .frame(width: pipWidth, height: pipHeight)
            }
        }
        // #1069
        .animation(reduceMotion ? nil : .default, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L("onboarding.progress.axlabel", "Setup progress")
        )
        .accessibilityValue(
            L(
                "onboarding.progress.axvalue",
                "Step %1$d of %2$d",
                index + 1,
                steps.count
            )
        )
    }
}
