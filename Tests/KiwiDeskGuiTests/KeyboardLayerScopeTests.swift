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
        // Order is the config file's own, and `KeybindingMerge`
        // APPENDS a recovered default — so a fixture with the
        // default at index 0 cannot tell "prefer the default"
        // from "take the first" (guard-prover, 2026-09-04).
        let appended = [
            layer("media", ["ctrl+alt+k"]),
            layer(KeyLayer.defaultName, ["ctrl+alt+j"]),
        ]
        #expect(
            KeyboardCensus.shown("gone", in: appended)
                .map(\.name) == [KeyLayer.defaultName]
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
        // environment the rows read never reaches it. WHERE the
        // selection lands is `nav`'s and may be retuned there;
        // this pins only that the panel takes its reading.
        #expect(
            panel.contains(
                "KeyboardCensus.shown(model.nav."
                    + "shortcutsLayerSelection,"
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
        // The board names what it draws, on both channels —
        // and the caption ANNOUNCES the layer-free sentence,
        // the board's own description having said it already.
        #expect(panel.contains("layerLabel:layerLabel"))
        #expect(panel.contains("Text(caption)"))
        // Contiguous from the `Text` it names: the modifier is
        // right for THIS view and wrong on any other, and moved
        // onto a sibling it passed a whole-file `contains`
        // while the layer went back to being announced twice
        // (guard-prover, 2026-09-04). Nothing drawn is swept
        // into the run — the styling follows it.
        #expect(
            panel.contains(
                "Text(caption).accessibilityLabel(draftCaption)"
            )
        )
        // The naming condition is the gate's, asked not counted.
        #expect(
            panel.contains(
                "ShortcutsGates(config:model.config)"
                    + ".inertReason(for:.shortcuts(.switchToLayer))"
            )
        )
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
                "model.nav.shortcutsLayerSelection"
            )
        )
        // Both strip mounts take that binding, not a local one.
        #expect(section.occurrences(of: "selected:selection") == 2)
        #expect(section.occurrences(of: "@Stateprivatevarselected") == 0)
    }

    /// The two needles above pin the two readers that exist; a
    /// THIRD spelling the coalescing inline is what actually
    /// happened to `layoutModeTab`, whose two readers now
    /// answer different defaults. Negative and tree-wide, so it
    /// reds on the reader nobody thought to needle — the `??`
    /// is the subject, never the raw field, which
    /// `resetSurfaces` and `ensureSelection` write legitimately.
    @Test("the landing is coalesced in exactly one place")
    func oneCoalescingInTheTree() throws {
        let root = Self.root
            .appendingPathComponent("Sources/KiwiDesk")
        var homes: [String] = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            let count = source.occurrences(of: "shortcutsLayer??")
            if count > 0 {
                homes.append(
                    "\(file.lastPathComponent) x\(count)"
                )
            }
        }
        #expect(
            homes == ["SettingsNavigation.swift x1"],
            Comment(
                rawValue:
                    "the selection's landing is spelled in "
                    + homes.joined(separator: ", ")
            )
        )
    }

    /// The header names the same layer under the same condition,
    /// so it asks the same resolver. It was the copy the panel's
    /// retired docstring pointed at, and nothing scanned it —
    /// `ShortcutsGateTests` is keyed on `LayersCard` and the
    /// clause above on the panel (re-review 2026-09-04).
    @Test("the header asks the gate whether to name the layer")
    func headerAsksTheResolver() throws {
        let header = try Self.source(
            "Sections/ShortcutsHeader.swift"
        )
        #expect(
            header.contains(
                "ShortcutsGates(config:model.config)"
                    + ".inertReason(for:.shortcuts(.switchToLayer))"
            )
        )
        #expect(header.occurrences(of: "layers.count") == 0)
    }
}

/// The half a source scan cannot reach: whether the panel ever
/// RESOLVES a name to put in front of the reader. Pinning that
/// the sentence builds correctly when handed a label, and that
/// the token is passed at the call site, leaves "the label is
/// always nil" green on both channels at once — which is #1127's
/// second claim regressing whole (guard-prover, 2026-09-04).
///
/// Main-actor spend (tests.md): two `makeTestModel` builds, each
/// minting a scratch defaults domain and a test core, and four
/// `L()` reads. No source scan, no filesystem walk and no AppKit
/// measurement — it is `@MainActor` only because the properties
/// it reads are `View` properties.
@MainActor
@Suite("Keyboard preview layer naming")
struct KeyboardLayerNamingTests {
    private func model(_ names: [String]) -> SettingsModel {
        let model = makeTestModel()
        model.config.layers = names.map { KeyLayer(name: $0) }
        return model
    }

    @Test("the sole layer is not named, a chosen one is")
    func labelFollowsTheLayerCount() {
        LocalizationManager.shared.select("en")
        let alone = model([KeyLayer.defaultName])
        let panel = KeyboardPreviewPanel(model: alone)
        #expect(panel.layerLabel == nil)
        #expect(
            panel.caption
                == "Shows your draft, not the saved profile."
        )

        let two = model([KeyLayer.defaultName, "media"])
        two.nav.shortcutsLayer = "media"
        let named = KeyboardPreviewPanel(model: two)
        #expect(named.layerLabel == "media")
        #expect(named.caption.contains("media"))
        #expect(named.shown.map(\.name) == ["media"])
    }

    /// The strip's landing, unwritten: the panel names the layer
    /// it actually drew rather than the one nav happens to hold,
    /// so the two channels cannot disagree with the caps.
    ///
    /// This arm asserts WHERE an unwritten selection lands, so
    /// retuning `shortcutsLayerSelection` owes this test and
    /// `SpaceOverridesNavTests` together — a behaviour claim
    /// about an opening the user sees, not a #1021 value pin.
    @Test("an unwritten selection still names what it drew")
    func labelNamesTheDrawnLayer() {
        LocalizationManager.shared.select("en")
        let two = model([KeyLayer.defaultName, "media"])
        let panel = KeyboardPreviewPanel(model: two)
        #expect(panel.layerLabel == KeyLayer.defaultName)
        two.nav.shortcutsLayer = "gone"
        #expect(
            KeyboardPreviewPanel(model: two).layerLabel
                == KeyLayer.defaultName
        )
    }
}
