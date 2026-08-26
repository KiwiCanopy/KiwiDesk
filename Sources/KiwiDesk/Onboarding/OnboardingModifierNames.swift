import KiwiDeskCore

/// One modifier of a tour chord: its glyph, and the key's short
/// name under it (#1016).
struct OnboardingModifierName: Identifiable, Equatable {
    var id: String { glyph }
    /// Looked up through `ComboSymbols`, never written — the same
    /// obligation every other glyph in this step carries.
    let glyph: String
    /// Never empty. A bare glyph among named ones reads as a
    /// rendering fault rather than as a decision (owner, on
    /// device, 2026-08-26): ⇧ was drawn without one for exactly
    /// one build, on the argument that everybody knows it, and it
    /// simply looked broken.
    let name: String
}

/// The words under the tour's modifier glyphs.
///
/// **Not localized, and deliberately so** (owner, 2026-08-26).
/// `ctrl` / `opt` / `shift` / `cmd` are read the same way in
/// every language this app ships — they are the abbreviations
/// every locale's own technical writing already uses, and two of
/// them are literally what a non-US Apple keyboard prints on the
/// cap. So they are language-neutral tokens like the glyphs above
/// them, not narration, and catalog keys would buy nothing while
/// adding four strings that can be mistranslated and one more
/// line on every future locale round. If a locale ever genuinely
/// needs its own, the reversal is to route these four through
/// `L()` — nothing else here would change.
///
/// **Two earlier drafts were wrong, and the reasons are worth
/// keeping.** The first wrote the KEY CAP's printing per locale
/// (German "alt"), which used the UI language as a proxy for the
/// physical keyboard — wrong for anyone running German on a US
/// layout — and coined a second name for a key
/// `key_recorder.help_press` already names one screen away. The
/// second used that screen's full words (Control / Option /
/// Command), which is right about the vocabulary.
///
/// **The width argument is about MARGIN, not about fitting.**
/// Measured against the 560 pt window (`OnboardingView`), the
/// widest seeded row with full names fits in every locale — but
/// German fits by 2.3 pt, one longer label or one wider
/// translation from wrapping, where the abbreviations leave
/// 37 pt. `OnboardingModifierNameTests` ▸ `namesStayShort` is
/// the one home for those numbers; do not restate them.
///
/// An abbreviation of the app's own word is not a second word:
/// the reader who wants the full name meets it in the Shortcuts
/// editor, spelled the way this catalog spells it there.
@MainActor
enum OnboardingModifierNames {
    /// The modifiers `chord` carries, in the canonical ⌃⌥⇧⌘ order
    /// `ComboSymbols` writes them in — so the caps read as the
    /// same chord every other surface of the app draws.
    ///
    /// A hand-mirror of that order, which
    /// `OnboardingModifierNameTests` derives rather than
    /// restates: concatenating these glyphs must equal the one
    /// string `ComboSymbols.modifierSymbols` produces for the
    /// same set.
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
