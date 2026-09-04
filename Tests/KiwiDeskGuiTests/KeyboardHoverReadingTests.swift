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

    private func layer(
        _ combos: [(String, String)],
        name: String = KeyLayer.defaultName
    ) -> KeyLayer {
        KeyLayer(
            name: name,
            bindings: combos.map {
                KeyBinding(
                    combo: $0.0,
                    lua: $0.1,
                    kind: .navigation,
                    label: "row"
                )
            }
        )
    }

    private func config(_ layers: [KeyLayer]) -> GuiConfig {
        var c = GuiConfig()
        c.layers = layers
        return c
    }

    /// j = 38 in the matrix.
    private let j: UInt32 = 38

    @Test("a claimed key names its chord and its action")
    func claimNamesTheAction() {
        LocalizationManager.shared.select("en")
        let layers = [
            layer([("ctrl+alt+j", "KiwiDesk.focus(\"left\")")])
        ]
        let reading = KeyboardHoverReading.of(
            j,
            in: layers,
            selected: [Layer(modifiers: [.control, .option])],
            config: config(layers),
            disabled: [],
            labels: ["KiwiDesk.focus(\"left\")": "Focus left"]
        )
        #expect(reading.claims.count == 1)
        #expect(reading.lines == ["⌃⌥J — Focus left"])
    }

    /// The scope the fills read is the scope the words read: a
    /// claim under a modifier the board is not showing must not
    /// appear, or the strip names an action on a key the cap
    /// draws as free.
    @Test("a claim outside the shown scope is not named")
    func claimsFollowTheScope() {
        LocalizationManager.shared.select("en")
        let layers = [
            layer([("cmd+j", "KiwiDesk.focus(\"left\")")])
        ]
        let reading = KeyboardHoverReading.of(
            j,
            in: layers,
            selected: [Layer(modifiers: [.control, .option])],
            config: config(layers),
            disabled: [],
            labels: [:]
        )
        #expect(reading.claims.isEmpty)
        #expect(reading.lines == ["J — not bound"])
    }

    /// The whole point of the feature (#798): the ring says two
    /// bindings clash and cannot say WHICH two. The cost
    /// sentence is `ConflictText`'s verbatim — #1126 forbids a
    /// second wording beside it — so this asserts the join, not
    /// the copy.
    @Test("a collision names both actions and its cost")
    func collisionNamesBothSides() {
        LocalizationManager.shared.select("en")
        let layers = [
            layer([
                ("ctrl+alt+j", "KiwiDesk.focus(\"left\")"),
                ("ctrl+alt+j", "KiwiDesk.swap(\"left\")"),
            ])
        ]
        let reading = KeyboardHoverReading.of(
            j,
            in: layers,
            selected: [Layer(modifiers: [.control, .option])],
            config: config(layers),
            disabled: [],
            labels: [
                "KiwiDesk.focus(\"left\")": "Focus left",
                "KiwiDesk.swap(\"left\")": "Swap left",
            ]
        )
        #expect(reading.claims.count == 2)
        #expect(reading.lines.count > 2)
        #expect(reading.lines[0] == "⌃⌥J — Focus left")
        #expect(reading.lines[1] == "⌃⌥J — Swap left")
        // …and the cost, from the one place it is worded.
        let expected = ConflictText.reading(
            for: layers[0].bindings[0],
            in: layers[0].bindings,
            config: config(layers),
            disabled: []
        )?.sentence
        #expect(expected != nil)
        #expect(reading.lines.contains(expected ?? "—"))
    }

    /// A free key macOS owns explains its own dashed ring, from
    /// the same map the ring draws from.
    @Test("a reserved free key names macOS's owner")
    func reservedKeyNamesItsOwner() {
        LocalizationManager.shared.select("en")
        // ⌘Space is Spotlight's, and nothing of ours claims it.
        let command = Layer(modifiers: .command)
        let reading = KeyboardHoverReading.of(
            49,
            in: [layer([])],
            selected: [command],
            config: config([layer([])]),
            disabled: [],
            labels: [:]
        )
        #expect(reading.claims.isEmpty)
        #expect(reading.freeOwner != nil)
        #expect(reading.lines.count == 1)
        #expect(reading.lines[0].contains("space"))
    }
}

/// The slot's reservation, asserted as ARITHMETIC (gui.md: a
/// count-driven preview is guarded by its arithmetic, never by a
/// scan for the input). A constant here nudges the panel under
/// the pointer on the COMMON case — a seeded install puts three
/// claims on a digit under `.all`.
///
/// Main-actor spend (tests.md): one `makeTestModel`, no scan, no
/// filesystem walk.
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
                        kind: .navigation
                    )
                }
            )
        ]
        return KeyboardPreviewPanel(model: model)
    }

    @Test("the reservation follows the deepest key on the board")
    func heightFollowsTheDeepestKey() {
        let one = panel(["ctrl+alt+j"])
        let three = panel([
            "ctrl+alt+1", "ctrl+alt+shift+1", "ctrl+alt+cmd+1",
        ])
        #expect(three.slotHeight > one.slotHeight)
        // Three claims on one key is the seeded shape, so the
        // reservation must clear three lines, not two.
        #expect(three.slotHeight >= one.slotHeight * 3)
    }

    @Test("a conflict ring reserves its cost sentence too")
    func conflictAddsItsLine() {
        let plain = panel(["ctrl+alt+j"])
        // Two bindings on ONE combo is the red ring, and the
        // reading carries the cost under the two claims.
        let ringed = panel(["ctrl+alt+j", "ctrl+alt+j"])
        #expect(ringed.slotHeight > plain.slotHeight)
    }

    @Test("an empty board still reserves a line")
    func emptyBoardKeepsTheTally() {
        // The slot always says something — the tally — so a
        // floor of zero would collapse it on a fresh profile.
        #expect(panel([]).slotHeight > 0)
    }
}
