import KiwiDeskCore

/// One modifier of a tour chord: its glyph and short name (#1016).
struct OnboardingModifierName: Identifiable, Equatable {
    var id: String { glyph }
    let glyph: String
    let name: String
}

/// Language-neutral short names under tour modifier glyphs
/// (OnboardingModifierNameTests).
@MainActor
enum OnboardingModifierNames {
    /// Modifiers in canonical ⌃⌥⇧⌘ order
    /// (OnboardingModifierNameTests).
    static func named(
        _ modifiers: HotkeyModifiers
    ) -> [OnboardingModifierName] {
        let names: [(HotkeyModifiers, String)] = [
            (.control, "ctrl"),
            (.option, "opt"),
            (.shift, "shift"),
            (.command, "cmd"),
        ]
        return names.compactMap { modifier, name in
            guard modifiers.contains(modifier) else { return nil }
            return OnboardingModifierName(
                glyph: ComboSymbols.modifierSymbols(modifier),
                name: name
            )
        }
    }
}
