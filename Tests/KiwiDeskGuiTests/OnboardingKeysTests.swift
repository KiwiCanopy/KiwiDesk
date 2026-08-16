import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's keys step reads the LIVE keymap (#678 Phase 4 pass
/// 11, turn 15a). Every assertion here is about a chord being
/// looked up rather than written: turn 15's own mock-up taught
/// `⌥1–5`, which is neither what the app seeds nor a modifier it
/// may use.
@Suite("Onboarding key families")
@MainActor
struct OnboardingKeysTests {
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

    private var arrows: [(String, String)] {
        [
            ("control+option+left", "KiwiDesk.focus(\"left\")"),
            ("control+option+down", "KiwiDesk.focus(\"down\")"),
            ("control+option+up", "KiwiDesk.focus(\"up\")"),
            ("control+option+right", "KiwiDesk.focus(\"right\")"),
        ]
    }

    private func spaces(_ count: Int) -> [SpaceID] {
        (1...count).map { SpaceID($0) }
    }

    @Test("a shared modifier set collapses to one prefix")
    func directionalCollapses() {
        let families = OnboardingKeys.families(
            layer: layer(arrows),
            spaces: []
        )
        let focus = families.first { $0.id == "focus" }
        // The modifiers once, then the four arrows — not four
        // repetitions of ⌃⌥.
        #expect(focus?.glyphs == "⌃⌥ ← ↓ ↑ →")
    }

    @Test("a rebound direction is shown, never averaged away")
    func directionalWithMixedModifiers() {
        // One arrow moved to a different chord. Collapsing would
        // print a prefix that is wrong for it, teaching the user
        // a chord they do not have.
        var mixed = arrows
        mixed[2] = ("control+command+up", "KiwiDesk.focus(\"up\")")
        let families = OnboardingKeys.families(
            layer: layer(mixed),
            spaces: []
        )
        let glyphs = families.first { $0.id == "focus" }?.glyphs
        #expect(glyphs?.contains("⌃⌘↑") == true)
        #expect(glyphs != "⌃⌥ ← ↓ ↑ →")
    }

    @Test("a space family renders as a range of its own digits")
    func spaceDigitsRange() {
        let bindings = (1...5).map { digit in
            (
                "control+option+\(digit)",
                "KiwiDesk.focus_space(\"\(digit)\")"
            )
        }
        let families = OnboardingKeys.families(
            layer: layer(bindings),
            spaces: spaces(5)
        )
        let go = families.first { $0.id == "focus_space" }
        #expect(go?.glyphs == "⌃⌥ 1–5")
    }

    @Test("one space is a digit, never a range of one")
    func singleSpaceIsNotARange() {
        let families = OnboardingKeys.families(
            layer: layer([
                (
                    "control+option+1",
                    "KiwiDesk.focus_space(\"1\")"
                )
            ]),
            spaces: spaces(1)
        )
        let go = families.first { $0.id == "focus_space" }
        #expect(go?.glyphs == "⌃⌥1")
        #expect(go?.glyphs.contains("–") == false)
    }

    /// A range is a claim that every digit between its ends
    /// works. `combos` is compacted, so a gap used to vanish and
    /// the range still spanned first→last.
    @Test("a gap in the digits is never written as a range")
    func gappedDigitsAreNotARange() {
        // Spaces 1…5 with ⌃⌥3 unbound.
        let bindings = [1, 2, 4, 5].map { digit in
            (
                "control+option+\(digit)",
                "KiwiDesk.focus_space(\"\(digit)\")"
            )
        }
        let families = OnboardingKeys.families(
            layer: layer(bindings),
            spaces: spaces(5)
        )
        let go = families.first { $0.id == "focus_space" }
        #expect(go != nil)
        #expect(
            go?.glyphs.contains("–") == false,
            "wrote a range over a gap: \(go?.glyphs ?? "")"
        )
        // …and it must not claim the missing digit either way.
        #expect(go?.glyphs.contains("1–5") == false)
    }

    /// A run that stops short of the space list is still a run.
    /// The tour states what is BOUND, so "⌃⌥ 1–3" over five
    /// spaces with three chords is true — and an earlier cut
    /// suppressed it with a clause nothing guarded.
    @Test("a truthful short run is still written as a range")
    func shortRunIsStillARange() {
        let bindings = (1...3).map { digit in
            (
                "control+option+\(digit)",
                "KiwiDesk.focus_space(\"\(digit)\")"
            )
        }
        let families = OnboardingKeys.families(
            layer: layer(bindings),
            spaces: spaces(5)
        )
        #expect(
            families.first { $0.id == "focus_space" }?.glyphs
                == "⌃⌥ 1–3"
        )
    }

    /// The tenth space binds ⌃⌥0, so "1–0" would run backwards.
    @Test("a ten-space setup is not written as 1–0")
    func tenSpacesIsNotAReversedRange() {
        var bindings = (1...9).map { digit in
            (
                "control+option+\(digit)",
                "KiwiDesk.focus_space(\"\(digit)\")"
            )
        }
        bindings.append(
            ("control+option+0", "KiwiDesk.focus_space(\"10\")")
        )
        let families = OnboardingKeys.families(
            layer: layer(bindings),
            spaces: spaces(10)
        )
        let go = families.first { $0.id == "focus_space" }
        #expect(go?.glyphs.contains("1–0") == false)
    }

    @Test("an unbound family draws no row at all")
    func unboundFamiliesAreOmitted() {
        // The tour teaches what is BOUND. A row with an empty
        // chord would be teaching nothing while looking like a
        // promise.
        let families = OnboardingKeys.families(
            layer: layer([]),
            spaces: spaces(3)
        )
        #expect(families.isEmpty)
    }

    @Test("an empty combo counts as unbound, not as a chord")
    func emptyComboIsNotAChord() {
        let families = OnboardingKeys.families(
            layer: layer([("", "KiwiDesk.focus(\"left\")")]),
            spaces: []
        )
        #expect(families.allSatisfy { !$0.glyphs.isEmpty })
        #expect(families.first { $0.id == "focus" } == nil)
    }

    @Test("every family carries a label and a chord")
    func familiesAreComplete() {
        let bindings =
            arrows
            + (1...3).map { digit in
                (
                    "control+option+\(digit)",
                    "KiwiDesk.focus_space(\"\(digit)\")"
                )
            }
            + [("control+option+k", ShortcutsOpenBinding.lua)]
        let families = OnboardingKeys.families(
            layer: layer(bindings),
            spaces: spaces(3)
        )
        #expect(families.count == 3)
        for family in families {
            #expect(!family.label.isEmpty)
            #expect(!family.glyphs.isEmpty)
        }
        // The panel's own opener is taught here, unlike in the
        // shortcuts panel where it is suppressed as a row — the
        // tour is where a user learns it exists.
        #expect(families.contains { $0.id == "shortcuts" })
    }

    /// The move/follow PAIR ships together (owner, 2026-08-16).
    ///
    /// The tour taught `move_to_space` alone while the seeded
    /// keymap binds move-and-follow on its own tier — so a reader
    /// learned one of two chords that differ only by where they
    /// leave you, and not the one most people reach for. Nothing
    /// noticed, because every other assertion here is about a
    /// family being looked up rather than about the SET being
    /// complete.
    @Test("the move and follow families ship together")
    func moveAndFollowAreBothTaught() {
        let bindings =
            (1...3).map { digit in
                (
                    "control+option+shift+\(digit)",
                    "KiwiDesk.move_to_space(\"\(digit)\")"
                )
            }
            + (1...3).map { digit in
                (
                    "control+option+command+\(digit)",
                    "KiwiDesk.move_to_space_and_follow"
                        + "(\"\(digit)\")"
                )
            }
        let families = OnboardingKeys.families(
            layer: layer(bindings),
            spaces: spaces(3)
        )
        let ids = Set(families.map(\.id))
        #expect(ids.contains("move_to_space"))
        #expect(ids.contains("move_to_space_and_follow"))
        // They must read as DIFFERENT actions: one label for two
        // chords teaches that the chords are interchangeable,
        // which is exactly what they are not.
        let moves = families.filter {
            $0.id.hasPrefix("move_to_space")
        }
        let labels = moves.map(\.label)
        #expect(Set(labels).count == labels.count)
        // And they carry different chords — the seeded tiers are
        // ⌃⌥⇧ against ⌃⌥⌘, so identical glyphs here would mean
        // one family had swallowed the other's lookup.
        let glyphs = moves.map(\.glyphs)
        #expect(Set(glyphs).count == glyphs.count)
    }

    @Test("nothing here writes a bare-Option chord")
    func neverTeachesBareOption() {
        // Bare Option is the macOS special-character modifier, so
        // ⌥L would swallow @ on international keyboards. The
        // scheme avoids it, and a LITERAL in the copy is how the
        // tour would teach it anyway (turn 15's mock-up did).
        let bindings =
            arrows
            + (1...5).map { digit in
                (
                    "control+option+\(digit)",
                    "KiwiDesk.focus_space(\"\(digit)\")"
                )
            }
        let families = OnboardingKeys.families(
            layer: layer(bindings),
            spaces: spaces(5)
        )
        #expect(!families.isEmpty)
        for family in families {
            #expect(
                family.glyphs.contains("⌃"),
                Comment(
                    rawValue:
                        "\(family.id) teaches \(family.glyphs), "
                        + "which drops the Control the seeded "
                        + "scheme uses"
                )
            )
        }
    }
}
