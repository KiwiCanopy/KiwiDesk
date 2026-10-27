import KiwiDeskCore

/// One modifier of a tour chord: its glyph and short name (#1016).
struct OnboardingModifierName: Identifiable, Equatable {
    var id: String { glyph }
    let glyph: String
    let name: String
}

/// Language-neutral short names under tour modifier glyphs, save
/// ✦, which takes Settings' own name for it (#2700).
/// `OnboardingModifierNameTests.namesStayShort` is the one home for those
/// numbers; do not restate them. An abbreviation of the app's own word is
/// not a second word.
@MainActor
enum OnboardingModifierNames {
    /// Modifiers in canonical ✦⌃⌥⇧⌘ order
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
        let hyper = OnboardingModifierName(
            glyph: ComboSymbols.hyperGlyph,
            name: hyperName
        )
        let plain: [OnboardingModifierName] = names.compactMap {
            modifier,
            name in
            guard modifiers.contains(modifier) else { return nil }
            return OnboardingModifierName(
                glyph: ComboSymbols.modifierSymbols(modifier),
                name: name
            )
        }
        return (modifiers.contains(.hyper) ? [hyper] : []) + plain
    }

    /// The Hyper key's name, the word Settings gives it.
    static var hyperName: String {
        L("shortcuts.hyper_key.name", "Hyper")
    }
}
