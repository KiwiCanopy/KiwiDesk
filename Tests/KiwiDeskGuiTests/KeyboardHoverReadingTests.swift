import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the board's status slot says about one key (#798).
///
/// The arithmetic, asserted directly rather than through the
/// drawing: a slot that takes the fold and renders a constant
/// satisfies any source scan while answering nothing — the
/// `LayoutSchematicCountTests` lesson, which gui.md rules for
/// exactly this shape.
///
/// Locale-pinned per body (tests.md): every line is an `L()`
/// frame.
@MainActor
@Suite("Keyboard hover reading")
struct KeyboardHoverReadingTests {
    private typealias Layer = KeyboardCensus.ModifierLayer
    private let ctrlOpt = Layer(modifiers: [.control, .option])
    private let command = Layer(modifiers: .command)
    /// j = 38, space = 49.
    private let j: UInt32 = 38

    private func layers(
        _ combos: [(String, String)]
    ) -> [KeyLayer] {
        [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: combos.map {
                    KeyBinding(
                        combo: $0.0,
                        lua: "KiwiDesk.focus(\"left\")",
                        kind: .navigation,
                        label: $0.1
                    )
                }
            )
        ]
    }

    private func config(_ l: [KeyLayer]) -> GuiConfig {
        var c = GuiConfig()
        c.layers = l
        return c
    }

    private func read(
        _ code: UInt32,
        _ l: [KeyLayer],
        scope: KeyboardCensus.Scope,
        selected: Set<Layer>
    ) -> KeyboardHoverReading {
        KeyboardHoverReading.of(
            code,
            in: l,
            scope: scope,
            selected: selected,
            config: config(l),
            disabled: []
        )
    }

    @Test("a claimed key names its chord and its action")
    func claimNamesTheAction() {
        LocalizationManager.shared.select("en")
        let l = layers([("ctrl+alt+j", "Focus left")])
        let r = read(
            j,
            l,
            scope: .one(ctrlOpt),
            selected: [ctrlOpt]
        )
        #expect(r.claims.count == 1)
        #expect(r.lines == ["⌃⌥J — Focus left"])
    }

    /// A bare binding has no chord to show, and the chip's PROSE
    /// is not one: `chipLabel` reads "No modifier", which welded
    /// itself onto the key and shipped "No modifierJ — Focus
    /// left" (localization audit, #798).
    @Test("a bare-modifier binding shows the key alone")
    func bareChordIsNotProse() {
        LocalizationManager.shared.select("en")
        let l = layers([("j", "Focus left")])
        let bare = Layer(modifiers: [])
        let r = read(j, l, scope: .one(bare), selected: [bare])
        #expect(r.lines == ["J — Focus left"])
    }

    /// Every fixture here used to put its bindings on ONE key,
    /// so the fold's `keyCode == code` filter was never
    /// exercised — dropping it made hovering any key name every
    /// action in the scope, green (guard-prover, 2026-09-05).
    @Test("a key names its own bindings, not the scope's")
    func claimsBelongToTheHoveredKey() {
        LocalizationManager.shared.select("en")
        // j = 38, k = 40, same layer.
        let l = layers([
            ("ctrl+alt+j", "Focus left"),
            ("ctrl+alt+k", "Focus right"),
        ])
        let r = read(
            j,
            l,
            scope: .one(ctrlOpt),
            selected: [ctrlOpt]
        )
        #expect(r.lines == ["⌃⌥J — Focus left"])
        #expect(!r.lines.joined().contains("Focus right"))
    }

    /// The documented order is the chip strip's, and only a
    /// fixture whose layers DIFFER can pin it: two claims in one
    /// layer swap under any sort, so the previous collision
    /// fixture proved order-sensitivity, not order.
    @Test("claims read in the chip strip's order")
    func claimsFollowTheChipOrder() {
        LocalizationManager.shared.select("en")
        // The strip leads with the FEWEST modifiers held, so ⌘
        // (one) precedes ⌃⌥ (two) whatever order they were
        // authored in — which is why this fixture authors them
        // the other way round.
        let l = layers([
            ("ctrl+alt+j", "Focus left"),
            ("cmd+j", "Command action"),
        ])
        let r = read(
            j,
            l,
            scope: .all,
            selected: [ctrlOpt, command]
        )
        #expect(r.claims.count == 2)
        #expect(r.lines[0] == "⌘J — Command action")
        #expect(r.lines[1] == "⌃⌥J — Focus left")
        // …and that IS the strip's own order, not a coincidence.
        #expect(
            KeyboardCensus.layers(in: l).map(\.label)
                == ["⌘", "⌃⌥"]
        )
    }

    /// The scope the fills read is the scope the words read: a
    /// claim under a modifier the board is not showing must not
    /// appear, or the strip names an action on a key the cap
    /// draws as free.
    @Test("a claim outside the shown scope is not named")
    func claimsFollowTheScope() {
        LocalizationManager.shared.select("en")
        let l = layers([("cmd+j", "Focus left")])
        let r = read(
            j,
            l,
            scope: .one(ctrlOpt),
            selected: [ctrlOpt]
        )
        #expect(r.claims.isEmpty)
        // The chip has fixed a chord, so the free line names it
        // too — a bare "J — not bound" answers about the key
        // rather than the combination being asked about (owner,
        // 2026-09-05).
        #expect(r.lines == ["⌃⌥J — not bound"])
    }

    /// The whole point of the feature: the ring says two
    /// bindings clash and cannot say WHICH two. The cost
    /// sentence is `ConflictText`'s verbatim — #1126 forbids a
    /// second wording — so this asserts the join and the
    /// PLACEMENT: each cost sits under its own claim.
    @Test("a collision names both actions, each with its cost")
    func collisionNamesBothSides() {
        LocalizationManager.shared.select("en")
        let l = layers([
            ("ctrl+alt+j", "Focus left"),
            ("ctrl+alt+j", "Swap left"),
        ])
        let r = read(
            j,
            l,
            scope: .one(ctrlOpt),
            selected: [ctrlOpt]
        )
        #expect(r.claims.count == 2)
        let expected = ConflictText.reading(
            for: l[0].bindings[0],
            in: l[0].bindings,
            config: config(l),
            disabled: []
        )?.sentence
        #expect(expected != nil)
        // Claim, its cost, claim, its cost — never both costs
        // orphaned at the bottom.
        #expect(r.lines.count == 4)
        #expect(r.lines[0] == "⌃⌥J — Focus left")
        #expect(r.lines[1] == expected)
        #expect(r.lines[2] == "⌃⌥J — Swap left")
    }

    /// A free key macOS owns explains its own dashed ring — and
    /// names the CHORD, since the reservation is a combination
    /// rather than a key.
    @Test("a reserved free key names the chord and its owner")
    func reservedKeyNamesItsOwner() {
        LocalizationManager.shared.select("en")
        let l = layers([])
        let r = read(
            49,
            l,
            scope: .one(command),
            selected: [command]
        )
        #expect(r.freeOwner != nil)
        #expect(r.lines.count == 1)
        #expect(r.lines[0].hasPrefix("⌘space — macOS owns this:"))
        #expect(r.scopeChord == "⌘")
    }

    /// The blocker this suite exists to hold: under `.all` the
    /// board draws NO reserved mark — macOS reserves a
    /// combination, not a key — so the words must say nothing
    /// about macOS either. `.all` is the panel's default scope,
    /// so this was the reading most users would have met.
    @Test("under All the words claim no reservation")
    func allScopeNamesNoOwner() {
        LocalizationManager.shared.select("en")
        let l = layers([])
        let r = read(
            49,
            l,
            scope: .all,
            selected: [command]
        )
        #expect(r.freeOwner == nil)
        // …and under All there is no single chord to name, so
        // the key stands alone. The two halves of one rule.
        #expect(r.lines == ["space — not bound"])
    }
}

/// The slot's reservation, asserted as ARITHMETIC (gui.md: a
/// count-driven preview is guarded by its arithmetic, never by a
/// scan for the input) — and as a COUNT, not an inequality: the
/// first cut compared `ringed > plain` and stayed green while
/// the reservation understated a collision by half, which is the
/// case the feature exists for (code review, #798).
///
/// Main-actor spend (tests.md): one `makeTestModel` per case, no
/// scan, no filesystem walk.
@MainActor
@Suite("Keyboard slot reservation")
struct KeyboardSlotHeightTests {
    private func panel(
        _ combos: [String]
    ) -> KeyboardPreviewPanel {
        let model = makeTestModel()
        model.config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: combos.map {
                    KeyBinding(
                        combo: $0,
                        lua: "KiwiDesk.focus(\"left\")",
                        kind: .navigation,
                        label: "Focus left"
                    )
                }
            )
        ]
        return KeyboardPreviewPanel(model: model)
    }

    @Test("the reservation counts the deepest key's own lines")
    func heightCountsTheDeepestReading() {
        LocalizationManager.shared.select("en")
        #expect(panel(["ctrl+alt+j"]).deepestReading == 1)
        // Three claims on one key — the seeded digit shape.
        #expect(
            panel([
                "ctrl+alt+1", "ctrl+alt+shift+1",
                "ctrl+alt+cmd+1",
            ]).deepestReading == 3
        )
        // A collision is a claim AND a cost per claim: two
        // bindings on one chord is FOUR lines, not two. Counting
        // claims alone read 1 here, because `claims` dedupes the
        // layer set.
        #expect(
            panel(["ctrl+alt+j", "ctrl+alt+j"])
                .deepestReading == 4
        )
    }

    @Test("the reservation follows the count, in points")
    func heightIsTheCountTimesALine() {
        LocalizationManager.shared.select("en")
        let one = panel(["ctrl+alt+j"])
        #expect(
            one.slotHeight
                == CGFloat(one.deepestReading)
                * KeyboardPreviewPanel.slotLine
        )
    }

    @Test("an empty board still reserves a line")
    func emptyBoardKeepsTheTally() {
        LocalizationManager.shared.select("en")
        // The slot always says something — the tally — so a
        // floor of zero would collapse it on a fresh profile.
        #expect(panel([]).deepestReading == 1)
        #expect(panel([]).slotHeight > 0)
    }
}
