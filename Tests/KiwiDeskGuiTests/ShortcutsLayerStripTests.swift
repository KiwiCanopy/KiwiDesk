import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The page-wide layer pick (#3535 ▸ Ruling 3): a strip above the
/// segment switcher, drawn once a layer exists, whose pick the
/// gesture cards edit too; Restore Defaults on `default` alone; a
/// layer's rename and delete carry its gestures.
@Suite("Shortcuts layer strip (#3535)")
@MainActor
struct ShortcutsLayerStripTests {
    private let swipe = GestureKey(.swipe3, [.control, .option])

    @Test("the strip leads the page, above the switcher, once a layer exists")
    func stripLeadsThePage() throws {
        let section = try squashed("Sections/ShortcutsSection.swift")
        #expect(
            section.contains(
                "VStack(spacing:0){layerStripsegmentControl(proxy)"
            )
        )
        let segment = try squashed("Sections/ShortcutsSection+Segment.swift")
        #expect(
            segment.contains(
                "ifShortcutsGates(config:model.config).layersExist"
                    + "{LayerStripEditor(model:model,selected:selection)"
            )
        )
    }

    @Test("Restore Defaults is drawn on default alone")
    func restoreOnDefault() throws {
        let card = try squashed("Components/Gestures/GestureListCard.swift")
        #expect(
            card.contains(
                "ifmodel.gestureScope.isDefault{Button("
                    + "GestureListWords.restoreDefaults,action:restore)"
            )
        )
    }

    @Test("an empty layer says the gestures are off")
    func emptyLayerSays() throws {
        let part = try squashed("Components/Gestures/GesturesPart.swift")
        #expect(
            part.contains(
                "ifletempty=emptyLayer{Text(LayerScopeWords"
                    + ".noGestures(empty))"
            )
        )
        let coding = GestureSeedScope(shortcutBase: .standard, layer: "x")
        let off = GestureMap([swipe: .unbound])
        #expect(GesturesPart.emptyLayer(GestureMap(), scope: coding) == "x")
        #expect(GesturesPart.emptyLayer(off, scope: coding) == "x")
        let bound = GestureMap([swipe: .bound(.family(.space))])
        #expect(GesturesPart.emptyLayer(bound, scope: coding) == nil)
        #expect(
            GesturesPart.emptyLayer(
                GestureMap(),
                scope: .defaultLayer(on: .standard)
            ) == nil
        )
    }

    @Test("what no layer owns says so, once a layer exists")
    func everyLayerNotes() throws {
        let card = try squashed("Components/Gestures/GestureListCard.swift")
        #expect(
            card.contains(
                "ifShortcutsGates(config:model.config).layersExist"
                    + "{Text(LayerScopeWords.everyLayer)"
            )
        )
        let keys = try squashed(
            "Components/Keybindings/ModifierKeysCard.swift"
        )
        #expect(
            keys.contains(
                "help:ShortcutsGates(config:model.config).layersExist"
                    + "?LayerScopeWords.everyLayer:nil"
            )
        )
    }

    @Test("the cards edit the picked layer's map")
    func cardsFollowThePick() {
        let model = makeTestModel()
        model.config.layers.append(KeyLayer(name: "Coding"))
        model.nav.shortcutsLayer = "Coding"
        model.config.gesture["default"] = GestureMap([
            swipe: .bound(.family(.space))
        ])
        #expect(model.gestureLayerMap[swipe] == nil)
        model.gestureLayerMap[swipe] = .bound(.family(.layout))
        #expect(model.gestureLayerMap[swipe] == .bound(.family(.layout)))
        #expect(model.config.gesture["Coding"][swipe] != nil)
        #expect(
            model.config.gesture["default"][swipe] == .bound(.family(.space))
        )
        #expect(
            model.gestureReachKey(swipe)
                == LayerGestureKey("Coding", swipe).spelling
        )
    }

    @Test("a layer's rename carries its gestures, its delete drops them")
    func layerEditsCarryGestures() {
        let model = makeTestModel()
        model.config.layers.append(KeyLayer(name: "Coding"))
        model.config.gesture["Coding"] = GestureMap([
            swipe: .bound(.family(.layout))
        ])
        model.renameLayer("Coding", to: "Code")
        #expect(model.config.gesture["Coding"].isEmpty)
        #expect(model.config.gesture["Code"][swipe] != nil)
        model.deleteLayer("Code", .everywhere)
        #expect(model.config.gesture["Code"].isEmpty)
    }

    @Test("a layer's rename and delete carry its rows' picks")
    func layerEditsCarryPicks() {
        let model = makeTestModel()
        model.config.layers.append(KeyLayer(name: "Coding"))
        let old = LayerGestureKey("Coding", swipe).spelling
        let new = LayerGestureKey("Code", swipe).spelling
        let other = swipe.spelling
        var edits = model.reachEdits
        edits.reach[.gesture] = [old: .listed(["Home"])]
        edits.removal[.gesture] = [old: .here, other: .here]
        model.reachEdits = edits
        model.renameLayer("Coding", to: "Code")
        #expect(model.reachEdits.reach[.gesture] == [new: .listed(["Home"])])
        #expect(
            model.reachEdits.removal[.gesture] == [new: .here, other: .here]
        )
        model.deleteLayer("Code", .everywhere)
        #expect(model.reachEdits.reach[.gesture]?.isEmpty != false)
        #expect(model.reachEdits.removal[.gesture] == [other: .here])
    }

    private func squashed(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }
}
