import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's tier sentence is DERIVED from the live keymap
/// (#1016), and this suite is about the half that matters: when
/// it must say NOTHING.
///
/// "`⌃⌥` moves your focus, add `⇧` to move the window" is a claim
/// about two modifier sets. A user who rebound swap off `⌃⌥⇧`
/// would be taught a chord they do not have — on the one screen
/// whose whole premise is that every glyph in it was looked up
/// rather than written.
///
/// `.serialized` and locale-pinned for the reason
/// `ConfigIssueTextTests` carries: `LocalizationManager` is a
/// process-wide singleton other suites `select()` into
/// concurrently.
@Suite("Onboarding tier anchor", .serialized)
@MainActor
struct OnboardingTierAnchorTests {
    private func layer(
        _ bindings: [(String, String)]
    ) -> KeyLayer {
        var layer = KeyLayer.defaultLayer
        layer.bindings = bindings.map { combo, lua in
            KeyBinding(
                combo: combo,
                lua: lua,
                kind: .navigation,
                label: lua
            )
        }
        return layer
    }

    /// The seeded tiers: ⌃⌥ focuses, ⌃⌥⇧ moves.
    private func seeded(
        focus: String = "control+option",
        move: String = "control+option+shift"
    ) -> [(String, String)] {
        let directions = ["left", "down", "up", "right"]
        return
            directions.map {
                ("\(focus)+\($0)", "KiwiDesk.focus(\"\($0)\")")
            }
            + directions.map {
                ("\(move)+\($0)", "KiwiDesk.swap(\"\($0)\")")
            }
            + (1...3).map {
                (
                    "\(focus)+\($0)",
                    "KiwiDesk.focus_space(\"\($0)\")"
                )
            }
            + (1...3).map {
                (
                    "\(move)+\($0)",
                    "KiwiDesk.move_to_space(\"\($0)\")"
                )
            }
    }

    private func anchor(
        _ bindings: [(String, String)]
    ) -> String? {
        OnboardingKeys.tierAnchor(
            OnboardingKeys.families(
                layer: layer(bindings),
                spaces: (1...3).map { SpaceID($0) }
            )
        )
    }

    /// **On a NON-seeded keymap, deliberately.** With the seeded
    /// chords a hardcoded `"⌃⌥"` in the copy is byte-identical to
    /// the derived one, so the old fixture could not tell the
    /// derivation from the literal — and a literal is precisely
    /// what `OnboardingKeys`' header forbids ("every glyph here
    /// is looked up, never written"; turn 15's mock-up taught
    /// `⌥1–5`, a chord the app does not bind). Rebinding both
    /// tiers onto ⌃⌘ / ⌃⌘⇧ makes the two answers differ, so the
    /// clause has something to distinguish (`guard-prover`,
    /// 2026-08-26).
    @Test("the tiers are stated with the keymap's own glyphs")
    func tiersAreReadFromTheLiveKeymap() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let sentence = anchor(
            seeded(
                focus: "control+command",
                move: "control+command+shift"
            )
        )
        #expect(sentence != nil)
        #expect(sentence?.contains("⌃⌘") == true)
        // The seeded modifier must NOT appear: it would mean the
        // copy carries a literal rather than a lookup.
        #expect(sentence?.contains("⌥") == false)
        // And the second clause names ⇧ ALONE — rendering the
        // whole tier-2 set there teaches a chord as an addition,
        // which is a different instruction.
        //
        // DERIVED through `ComboSymbols` rather than typed: the
        // canonical order is ⌃⌥⇧⌘, so the hand-written form
        // this replaced named a string the app never produces,
        // and the clause passed under the very mutation it was
        // written for.
        let wholeTier = ComboSymbols.modifierSymbols([
            .control, .command, .shift,
        ])
        #expect(sentence?.contains(wholeTier) == false)
    }

    /// The defect the sentence could ship: a rebound tier 2 and a
    /// sentence that still names ⇧.
    @Test("a tier moved off shift is not claimed anyway")
    func rebounToADifferentTierSaysNothing() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            anchor(seeded(move: "control+option+command")) == nil
        )
    }

    /// Shift ALREADY in tier 1 makes "add ⇧" meaningless: there
    /// is nothing to add, and the sentence would read "⌃⌥⇧ moves
    /// your focus. Add ⇧ to move the window."
    ///
    /// **The two tiers are the SAME chord here, deliberately.**
    /// A shifted tier 1 with an ordinary tier 2 above it is
    /// already rejected by the union clause, so a fixture like
    /// that reaches this one never — the first cut of this test
    /// used one and passed with `!base.contains(.shift)` deleted
    /// (proven by mutation, 2026-08-26). Only where
    /// `base ∪ ⇧ == base` — which is to say where base already
    /// has it — does the union clause wave the keymap through and
    /// this clause become the one thing standing in front of the
    /// nonsense sentence.
    @Test("shift already in the focus tier says nothing")
    func shiftInTheBaseSaysNothing() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            anchor(
                seeded(
                    focus: "control+option+shift",
                    move: "control+option+shift"
                )
            ) == nil
        )
    }

    /// Two families on ONE tier disagreeing is the same lie in a
    /// quieter form: `⌃⌥` moves the focus with the arrows and
    /// something else with the digits.
    @Test("families inside one tier disagreeing says nothing")
    func splitTierSaysNothing() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        var bindings = seeded()
        bindings = bindings.map { combo, lua in
            lua.contains("focus_space")
                ? (
                    combo.replacingOccurrences(
                        of: "control+option",
                        with: "control+command"
                    ), lua
                )
                : (combo, lua)
        }
        #expect(anchor(bindings) == nil)
    }

    /// **Each `movesWindow` family, separately.** Dropping
    /// `tier: .movesWindow` from `swap` or from `move_to_space`
    /// left the whole lane green, because no fixture ever
    /// rebound one of the pair alone (`guard-prover`,
    /// 2026-08-26) — so the field introduced to stop a rename
    /// desyncing the derivation could itself be deleted
    /// silently. The `movesFocus` pair is covered by
    /// `splitTierSaysNothing` and `mixedFamilySaysNothing`.
    @Test("one rebound window family alone says nothing")
    func splitWindowTierSaysNothing() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        for moved in ["swap", "move_to_space"] {
            let bindings = seeded().map { combo, lua in
                lua.contains(moved)
                    ? (
                        combo.replacingOccurrences(
                            of: "control+option+shift",
                            with: "control+option+command"
                        ), lua
                    )
                    : (combo, lua)
            }
            #expect(
                anchor(bindings) == nil,
                Comment(
                    rawValue:
                        "\(moved) moved to its own tier and "
                        + "the sentence still claimed one"
                )
            )
        }
    }

    /// A family edited apart has no shared set at all, so there
    /// is no tier to name — the `mixed` case, which the
    /// derivation must read as absence rather than as a default.
    @Test("a family with no shared prefix says nothing")
    func mixedFamilySaysNothing() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        var bindings = seeded()
        bindings[2] = (
            "control+command+up", "KiwiDesk.focus(\"up\")"
        )
        #expect(anchor(bindings) == nil)
    }

    /// **A bare-key tier 1 renders the sentence with no subject**
    /// — " moves your focus. Add ⇧ to move the window.", leading
    /// space and all, on the one screen whose whole premise is
    /// that nothing is asserted (`code-reviewer`, 2026-08-26).
    ///
    /// Bare-key bindings are a modelled case, not a hypothetical:
    /// `KeyCombo.parse("left")` succeeds with an empty modifier
    /// set, and `KeyboardCensus.ModifierLayer.label` documents
    /// the empty layer. Every other clause waves it through — an
    /// empty set contains no shift, and `[] ∪ ⇧ == [⇧]` — so
    /// emptiness is its own question.
    ///
    /// It is also why the frame needs no `WITHHELD_ARGUMENTS`
    /// entry: `%1$@` is first rather than last, and the fix is to
    /// never render it empty rather than to legalise doing so.
    @Test("a bare-key focus tier says nothing")
    func bareKeyTierSaysNothing() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let directions = ["left", "down", "up", "right"]
        let bindings =
            directions.map {
                ($0, "KiwiDesk.focus(\"\($0)\")")
            }
            + directions.map {
                ("shift+\($0)", "KiwiDesk.swap(\"\($0)\")")
            }
        #expect(anchor(bindings) == nil)
    }

    @Test("an unbound keymap says nothing")
    func nothingBoundSaysNothing() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(anchor([]) == nil)
    }

    /// Tier 1 alone is not the rule — the sentence's second
    /// clause has no subject.
    @Test("focus alone is not enough to state the rule")
    func focusAloneSaysNothing() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let onlyFocus = seeded().filter {
            $0.1.contains("focus")
        }
        #expect(anchor(onlyFocus) == nil)
    }
}
