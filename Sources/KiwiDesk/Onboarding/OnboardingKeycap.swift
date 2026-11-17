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
            case .mixed(let chords):
                // One cap per chord, so a side word or modifier
                // reads as its own chord's alone (#2877).
                ForEach(Array(chords.enumerated()), id: \.offset) {
                    chip($0.element)
                }
            case .gesture(let modifiers, let glyph, let caption):
                ForEach(
                    OnboardingModifierNames.named(modifiers)
                ) { modifier in
                    namedChip(modifier)
                    plus
                }
                gestureChip(glyph, caption)
            }
        }
        // Whole or not at all: a tight row wraps its label rather
        // than squeezing a "+" to nothing (#3426).
        .fixedSize()
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

    /// A gesture's cap (#3427): KiwiHub's glyph on a keycap, its
    /// finger count or motion under it as a modifier's name sits.
    private func gestureChip(
        _ glyph: String,
        _ caption: String
    ) -> some View {
        VStack(spacing: 3) {
            GestureGlyph(symbol: glyph, side: Self.glyphSide)
                .keycapChrome()
            Text(caption)
                .font(.system(size: 9.5))
                .foregroundStyle(SettingsTheme.ink3)
        }
        .fixedSize()
        .accessibilityHidden(true)
    }

    /// The gesture glyph's side on its cap.
    static let glyphSide: CGFloat = 16

    /// Separator between shortcut key chips.
    private var plus: some View {
        Text(verbatim: "+")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SettingsTheme.ink3)
            .padding(.vertical, 4)
    }

    /// Visual keycap chip, plain on every row (#2877).
    private func chip(_ text: String) -> some View {
        ChordKeycap(text: text)
    }
}
