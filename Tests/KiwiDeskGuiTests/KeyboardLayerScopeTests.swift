import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The board draws ONE keybinding layer (#1127): the picture
/// exists to answer "is this key free HERE", and a census folded
/// over every layer answers "is it bound anywhere" instead — a
/// different question, and the one the user never asked.
@Suite("Keyboard preview layer scope")
struct KeyboardLayerScopeTests {
    private func layer(
        _ name: String,
        _ combos: [String]
    ) -> KeyLayer {
        KeyLayer(
            name: name,
            bindings: combos.map {
                KeyBinding(combo: $0, lua: "focus_dir('left')")
            }
        )
    }

    private var pair: [KeyLayer] {
        [
            layer(KeyLayer.defaultName, ["ctrl+alt+j"]),
            layer("media", ["ctrl+alt+k"]),
        ]
    }

    @Test("the named layer is the one the board is taken over")
    func shownIsTheNamedLayer() {
        #expect(
            KeyboardCensus.shown("media", in: pair).map(\.name)
                == ["media"]
        )
        // j = 38, k = 40: the other layer's claim is absent, not
        // merely drawn differently.
        let shown = KeyboardCensus.shown("media", in: pair)
        let modifiers = Set(KeyboardCensus.layers(in: shown))
        let claims = KeyboardCensus.claims(
            in: shown,
            selected: modifiers
        )
        #expect(claims[40] != nil)
        #expect(claims[38] == nil)
        #expect(KeyboardCensus.takenKeyCount(claims: claims) == 1)
    }

    /// The strip's selection outlives a rename or a delete for
    /// as long as it takes the section to repair it, and a board
    /// drawing nothing in that gap reads as "every key is free".
    @Test("a name no layer answers to falls back, never empties")
    func unknownNameFallsBack() {
        #expect(
            KeyboardCensus.shown("gone", in: pair).map(\.name)
                == [KeyLayer.defaultName]
        )
        let noDefault = [layer("media", ["ctrl+alt+k"])]
        #expect(
            KeyboardCensus.shown("gone", in: noDefault)
                .map(\.name) == ["media"]
        )
        #expect(KeyboardCensus.shown("gone", in: []).isEmpty)
    }

    /// The one collision fold that must move with the scope too:
    /// conflicts are per layer, so a duplicate sitting in the
    /// layer the user is NOT editing may not ring a key here.
    @Test("a collision in the other layer stays off this board")
    func collisionsFollowTheDrawnLayer() {
        let layers = [
            layer(KeyLayer.defaultName, ["ctrl+alt+j", "ctrl+alt+j"]),
            layer("media", ["ctrl+alt+k"]),
        ]
        let shown = KeyboardCensus.shown("media", in: layers)
        #expect(
            KeyboardCensus.collisions(in: shown, scope: .all)
                .isEmpty
        )
        #expect(
            !KeyboardCensus.collisions(
                in: KeyboardCensus.shown(
                    KeyLayer.defaultName,
                    in: layers
                ),
                scope: .all
            ).isEmpty
        )
    }
}

/// The wiring half. `shown` answering correctly buys nothing
/// while the panel still hands the whole set to the census, and
/// nothing above a `body` can see which array a call took — the
/// Monitors lesson, keyed on the use sites.
@Suite("Keyboard preview layer wires")
struct KeyboardLayerWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func source(
        _ file: String
    ) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "Sources/KiwiDesk/Settings/\(file)"
                ),
                encoding: .utf8
            )
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    }

    @Test("every census fold in the panel takes the drawn layer")
    func panelFoldsOverOneLayer() throws {
        let panel = try Self.source(
            "Components/Keybindings/KeyboardPreviewPanel.swift"
        )
        // The layer arrives from the model, the panel being the
        // section's sibling — the `keybindingLayerName`
        // environment the rows read never reaches it.
        #expect(
            panel.contains(
                "KeyboardCensus.shown(model.nav.shortcutsLayer"
                    + "??KeyLayer.defaultName,"
                    + "in:model.config.layers)"
            )
        )
        // Every fold that decides a mark or a tally, by count:
        // one left on the whole set draws another layer's claim.
        #expect(panel.contains("KeyboardCensus.layers(in:shown)"))
        #expect(
            panel.contains(
                "KeyboardCensus.claims(in:shown,selected:selected)"
            )
        )
        #expect(
            panel.contains(
                "KeyboardCensus.collisions(in:shown,"
                    + "scope:liveScope)"
            )
        )
        #expect(
            panel.occurrences(of: "in:model.config.layers") == 1
        )
        // The board names what it draws, on both channels.
        #expect(panel.contains("layerLabel:layerLabel"))
        #expect(panel.contains("Text(caption)"))
    }

    /// The write the panel's read depends on: with the selection
    /// back on view `@State` every assertion above still passes
    /// and the board never moves off `default`.
    @Test("the section publishes its selection to the model")
    func sectionWritesTheSelection() throws {
        let section = try Self.source(
            "Sections/ShortcutsSection.swift"
        )
        #expect(
            section.contains("set:{model.nav.shortcutsLayer=$0}")
        )
        #expect(
            section.contains(
                "model.nav.shortcutsLayer??KeyLayer.defaultName"
            )
        )
        // Both strip mounts take that binding, not a local one.
        #expect(section.occurrences(of: "selected:selection") == 2)
        #expect(section.occurrences(of: "@Stateprivatevarselected") == 0)
    }
}
