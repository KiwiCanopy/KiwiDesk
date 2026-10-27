import KiwiDeskCore
import SwiftUI

/// A family's chord as the tour draws it: keycap chips with each
/// modifier named under its glyph, spoken as one glyph string
/// (#23, #1016). The keys step and the bars step (#2515) share it.
struct OnboardingKeycap: View {
    let family: OnboardingKeyFamily

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            switch family.chord {
            case .shared(let modifiers, let keys):
                ForEach(
                    OnboardingModifierNames.named(modifiers)
                ) { modifier in
                    namedChip(modifier)
                    plus
                }
                chip(keys)
            case .mixed(let text):
                chip(text)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(family.spokenGlyphs)
    }

    /// Single modifier chip with hidden accessibility label (#1016).
    private func namedChip(
        _ modifier: OnboardingModifierName
    ) -> some View {
        VStack(spacing: 3) {
            chip(modifier.glyph)
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
    private func chip(_ text: String) -> some View {
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
}
