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

    @Test("the seeded tiers are stated with their own glyphs")
    func seededTiersAreStated() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let sentence = anchor(seeded())
        #expect(sentence != nil)
        // Both halves are the LOOKED-UP glyphs, not literals in
        // the copy — the whole obligation of this step.
        #expect(sentence?.contains("⌃⌥") == true)
        #expect(sentence?.contains("⇧") == true)
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
