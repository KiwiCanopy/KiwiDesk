import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The trackpad gestures step (#1873 ▸ Ruling 2026-11-15,
    /// preview `tour-gestures-v2`): what a seeded gesture does, in
    /// words, then ⌃⌥K for every one.
    var gestures: some View {
        let rows = model.gestureFamilies
        return OnboardingPage(
            title: L("onboarding.gestures.title", "Your gestures"),
            body1: L(
                "onboarding.gestures.body",
                "These are ready on your trackpad. Hold the keys, then "
                    + "move your fingers."
            ),
            footnote: OnboardingGestures.teachesScreens(rows)
                ? L(
                    "onboarding.gestures.steps_screens",
                    "Focus keeps stepping while your fingers move. "
                        + "Spaces and screens take one step per swipe."
                )
                : L(
                    "onboarding.gestures.steps",
                    "Focus keeps stepping while your fingers move. "
                        + "Spaces take one step per swipe."
                ),
            hint: L(
                "onboarding.keys.hint",
                "Try one now — nothing will break."
            ),
            back: model.back
        ) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(rows) { family in
                    if family.isGateway {
                        Divider().padding(.vertical, 4)
                    }
                    gestureRow(family)
                }
            }
        } action: {
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterGestures()
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    private func gestureRow(_ family: OnboardingKeyFamily) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(family.label)
                .font(.system(size: 13.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            OnboardingKeycap(family: family)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(family.spoken ?? family.label)
    }
}
