import Foundation
import KiwiDeskCore

/// One line of the tour's keys step: what it does, and the chord
/// that does it.
struct OnboardingKeyFamily: Identifiable, Equatable {
    let id: String
    /// Localized, spoken and drawn from this one string.
    let label: String
    /// The chord(s), kept STRUCTURED rather than as one glyph
    /// string (#1016).
    let chord: OnboardingChord
    /// Whether this row opens the shortcuts reference panel (#828).
    var isGateway = false
    /// Which seeded modifier tier this family belongs to, if any.
    var tier: OnboardingKeyTier?

    /// The chord as a native glyph string for VoiceOver and mixed families.
    var glyphs: String { chord.glyphs }
}

/// Seeded modifier tiers for onboarding explanations (focus vs
/// window movement).
enum OnboardingKeyTier {
    case movesFocus
    case movesWindow
}

/// A family's chord structure retaining its modifier set (#1016).
enum OnboardingChord: Equatable {
    /// The modifiers every chord in the family shares, then the
    /// keys that differ — `⌃⌥` with `← ↓ ↑ →`, or with
    /// `1–5`.
    case shared(HotkeyModifiers, keys: String)
    /// A family edited apart, sharing no prefix: each chord
    /// written in full, and no modifier to name in words.
    case mixed(String)

    var glyphs: String {
        switch self {
        case .shared(let modifiers, let keys):
            let symbols = ComboSymbols.modifierSymbols(modifiers)
            guard !symbols.isEmpty else { return keys }
            guard !keys.isEmpty else { return symbols }
            // Space separator between modifier symbols and keys.
            return symbols + " " + keys
        case .mixed(let text):
            return text
        }
    }
}
