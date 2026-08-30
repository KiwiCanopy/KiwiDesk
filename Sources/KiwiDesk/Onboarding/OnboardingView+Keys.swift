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
            VStack(alignment: .leading, spacing: 8) {
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
            keycap(family)
        }
        .accessibilityElement(children: .combine)
    }

    /// Renders chord chips with modifier labels and separators (#23, #1016).
    @ViewBuilder private func keycap(
        _ family: OnboardingKeyFamily
    ) -> some View {
        HStack(alignment: .top, spacing: 5) {
            switch family.chord {
            case .shared(let modifiers, let keys):
                ForEach(
                    OnboardingModifierNames.named(modifiers)
                ) { modifier in
                    namedChip(modifier, family: family)
                    plus
                }
                chip(keys, family: family)
            case .mixed(let text):
                chip(text, family: family)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(family.glyphs)
    }

    /// Single modifier chip with hidden accessibility label (#1016).
    private func namedChip(
        _ modifier: OnboardingModifierName,
        family: OnboardingKeyFamily
    ) -> some View {
        VStack(spacing: 3) {
            chip(modifier.glyph, family: family)
            Text(modifier.name)
                .font(.system(size: 9.5))
                .foregroundStyle(SettingsTheme.ink3)
                .accessibilityHidden(true)
        }
        .fixedSize()
    }

    /// Separator between shortcut key chips.
    private var plus: some View {
        Text(verbatim: "+")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SettingsTheme.ink3)
            .padding(.vertical, 4)
    }

    /// Visual keycap chip; gateway chords draw accent ink on accent fill.
    private func chip(
        _ text: String,
        family: OnboardingKeyFamily
    ) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold).monospaced())
            .foregroundStyle(
                family.isGateway
                    ? SettingsTheme.accentInk
                    : SettingsTheme.ink
            )
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        family.isGateway
                            ? SettingsTheme.accent
                            : SettingsTheme.sunken
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        family.isGateway
                            ? SettingsTheme.accentInk.opacity(0.22)
                            : SettingsTheme.ink2.opacity(0.3),
                        lineWidth: 1.2
                    )
            )
    }

    private var keysTitle: String {
        L("onboarding.keys.title", "Your shortcuts")
    }
}
