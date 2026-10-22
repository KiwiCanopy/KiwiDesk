import KiwiDeskCore
import SwiftUI

extension OnboardingView {
    /// The shortcuts step teaching primary chord families (#331, #828).
    var keys: some View {
        let rows = model.keyFamilies()
        return OnboardingPage(
            title: keysTitle,
            body1: keysLead,
            footnote: OnboardingKeys.tierAnchor(rows),
            hint: L(
                "onboarding.keys.hint",
                "Try one now — nothing will break."
            )
        ) {
            families(rows)
        } action: {
            Button(L("onboarding.continue", "Continue")) {
                model.continueAfterKeys()
            }
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
        }
    }

    /// Explanatory intro text for the shortcut families (#678).
    private var keysLead: String {
        L(
            "onboarding.keys.body",
            "These are ready to use, on the keyboard you are "
                + "typing on."
        )
    }

    @ViewBuilder private func families(
        _ rows: [OnboardingKeyFamily]
    ) -> some View {
        if rows.isEmpty {
            Text(
                L(
                    "onboarding.keys.none",
                    "Your shortcuts are yours to set, and none "
                        + "are bound yet. Settings has the full "
                        + "list whenever you want it."
                )
            )
            .font(.system(size: 13.5))
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(rows) { row(for: $0) }
            }
        }
    }

    private func row(
        for family: OnboardingKeyFamily
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(family.label)
                .font(.system(size: 13.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            OnboardingKeycap(family: family)
        }
        .accessibilityElement(children: .combine)
    }

    private var keysTitle: String {
        L("onboarding.keys.title", "Your shortcuts")
    }
}
