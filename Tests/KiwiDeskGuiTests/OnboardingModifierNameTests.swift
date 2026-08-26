import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour draws one chip per modifier with the word printed on
/// that key under it (#1016), which makes
/// `OnboardingModifierNames` a hand-kept mirror of
/// `ComboSymbols.modifierSymbols` — the same four modifiers, in
/// the same canonical ⌃⌥⇧⌘ order, one level up.
///
/// So it is guarded the way `.claude/rules/parity-tests.md` asks:
/// the mirror is DERIVED against its original rather than
/// restated. A fifth modifier, a reordering, or a legend dropped
/// from the list all show up as the two disagreeing — none of
/// which a needle for `"⌃"` would see.
///
/// Nothing here is locale-pinned, and that is itself the point:
/// since #1016's third cut the names are language-neutral tokens
/// with no catalog keys at all, so a suite that had to `select()`
/// a locale would be asserting something this component no longer
/// does.
@Suite("Onboarding modifier names")
@MainActor
struct OnboardingModifierNameTests {
    /// Every subset of the four, so the mirror is checked against
    /// the original for each shape a chord can have rather than
    /// for the one the seeded keymap happens to use.
    private var everySet: [HotkeyModifiers] {
        let all: [HotkeyModifiers] = [
            .control, .option, .shift, .command,
        ]
        return (0..<16).map { mask in
            var set = HotkeyModifiers()
            for (bit, modifier) in all.enumerated()
            where mask & (1 << bit) != 0 {
                set.insert(modifier)
            }
            return set
        }
    }

    /// The whole mirror: the drawn glyphs, read left to right,
    /// ARE the string every other surface of the app writes.
    @Test("the caps spell the chord ComboSymbols writes")
    func capsSpellTheCanonicalChord() {
        for set in everySet {
            let drawn = OnboardingModifierNames.named(set)
                .map(\.glyph)
                .joined()
            #expect(
                drawn == ComboSymbols.modifierSymbols(set),
                Comment(
                    rawValue:
                        "the tour draws \(drawn) where the app "
                        + "writes \(ComboSymbols.modifierSymbols(set))"
                )
            )
        }
    }

    /// A glyph with no word under it is one the reader still
    /// cannot name — the entire defect #1016 is about — and it
    /// also simply looks broken beside three named ones (owner,
    /// on device, 2026-08-26, after ⇧ shipped bare for one
    /// build). Both halves are the same assertion: every glyph
    /// this step draws carries a word.
    @Test("every modifier carries a name")
    func everyModifierIsNamed() {
        let all: HotkeyModifiers = [
            .control, .option, .shift, .command,
        ]
        let named = OnboardingModifierNames.named(all)
        #expect(named.count == 4)
        for modifier in named {
            #expect(!modifier.name.isEmpty)
            #expect(!modifier.glyph.isEmpty)
        }
    }

    /// The name is drawn under a chip roughly two glyphs wide and
    /// repeats up to three times across one row of a 560 pt
    /// window.
    ///
    /// The measurement that settled this, and the ONE home for
    /// these numbers — the source and `docs/design-decisions.md`
    /// cite this suite rather than repeating them, all three
    /// having carried a wrong version of it (2026-08-26).
    ///
    /// Against the 560 pt window's 500 pt of content, the widest
    /// seeded row with the Shortcuts editor's FULL words fits in
    /// every locale — but German fits by about two points, where
    /// abbreviated it fits by tens. The bound is a MARGIN, not a
    /// failure. (An earlier version said full names did not fit
    /// at all: it had measured Italian's modifier names against
    /// a German label, a pairing that cannot occur, and the
    /// wrong number reached two other files and a ruling.)
    ///
    /// **The clause DERIVES the bound rather than restating it.**
    /// It was `name.count <= 5`, which is the length of the
    /// longest shipped token written down — a tautology that
    /// reds on a deliberate retune and catches no regression
    /// (`guard-prover`, 2026-08-26; `rule-authoring.md` ▸ a
    /// number-pin must derive the number). What actually matters
    /// is that a name is narrower than the chip above it, which
    /// is what keeps each column chip-bound and the words free.
    @Test("a name is narrower than the chip above it")
    func namesStayInsideTheirChip() {
        let nameFont = NSFont.systemFont(ofSize: 9.5)
        let glyphFont = NSFont.monospacedSystemFont(
            ofSize: 12,
            weight: .semibold
        )
        // The chip's own padding, from `OnboardingView.chip`.
        let horizontalPadding: CGFloat = 18
        let all: HotkeyModifiers = [
            .control, .option, .shift, .command,
        ]
        for modifier in OnboardingModifierNames.named(all) {
            let chip =
                (modifier.glyph as NSString)
                .size(withAttributes: [.font: glyphFont])
                .width + horizontalPadding
            let name =
                (modifier.name as NSString)
                .size(withAttributes: [.font: nameFont]).width
            #expect(
                name <= chip,
                Comment(
                    rawValue:
                        "\(modifier.name) is \(name) pt under a "
                        + "\(chip) pt chip — the column stops "
                        + "being chip-bound and the row grows"
                )
            )
        }
    }

    /// Naming a modifier the chord does not carry teaches a chord
    /// the user does not have.
    @Test("only the chord's own modifiers are drawn")
    func unsetModifiersAreNotDrawn() {
        let drawn = OnboardingModifierNames.named([
            .control, .option,
        ])
        #expect(drawn.count == 2)
        #expect(
            drawn.contains {
                $0.glyph
                    == ComboSymbols.modifierSymbols(.control)
            }
        )
        #expect(
            !drawn.contains {
                $0.glyph == ComboSymbols.modifierSymbols(.shift)
            }
        )
    }
}
