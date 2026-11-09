import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Key sequences card's tree edits and the surfaces naming a
/// sequence's path (#1871): the row caption, KiwiHub's Shortcuts
/// side, and the layer rewrites that reach end keys.
@Suite("Key sequence card (#1871)")
@MainActor
struct KeySequenceCardTests {
    private let left = KeybindingCatalog.focusDirections[0]

    private func sequence(endLua: String? = nil) -> KeyBinding {
        let end = KeyBinding(
            combo: "h",
            lua: endLua ?? left.lua,
            kind: .navigation,
            label: left.label
        )
        let branch = KeyBinding.sequence(
            combo: "w",
            label: "Windows",
            steps: [end, KeyBinding(combo: "j", kind: .navigation)]
        )
        return .sequence(
            combo: "ctrl+alt+space",
            label: "Leader",
            steps: [branch]
        )
    }

    @Test("an edit keeps the node's id and the decoder's pairing")
    func editsKeepShape() throws {
        let root = sequence()
        let end = try #require(root.steps?[0].steps?[0])
        let branched = SequenceTree.updating(end.id, in: root) {
            $0 = SequenceTree.branch($0, name: "More")
        }
        let node = try #require(SequenceTree.node(end.id, in: branched))
        #expect(node.isSequence && node.steps == [] && node.lua.isEmpty)
        let back = SequenceTree.updating(end.id, in: branched) {
            $0 = SequenceTree.endKey($0, running: left)
        }
        let key = try #require(SequenceTree.node(end.id, in: back))
        #expect(!key.isSequence && key.steps == nil && key.lua == left.lua)
        #expect(key.combo == "h")
        let gone = SequenceTree.removing(end.id, from: root)
        #expect(SequenceTree.node(end.id, in: gone) == nil)
        #expect(SequenceTree.keyCount(under: gone) == 2)
    }

    @Test("a sibling holds a chord in its step alone")
    func siblingIsStepScoped() throws {
        let root = sequence()
        let branch = try #require(root.steps?[0])
        let j = try #require(branch.steps?[1])
        #expect(
            SequenceTree.sibling(holding: "h", besides: j.id, in: root)?
                .lua == left.lua
        )
        // `w` is held one step up, never in `j`'s step.
        #expect(
            SequenceTree.sibling(holding: "w", besides: j.id, in: root)
                == nil
        )
        #expect(
            SequenceTree.sibling(holding: "ctrl+h", besides: j.id, in: root)
                == nil
        )
    }

    @Test("the action's row names the sequence that also runs it")
    func alsoCaption() {
        LocalizationManager.shared.select("en")
        let also = SequencePathWords.also(running: left, in: [sequence()])
        #expect(also?.hasPrefix("Also ") == true)
        #expect(also?.contains("\u{2192} W \u{2192} H") == true)
        let other = KeybindingCatalog.focusDirections[1]
        #expect(
            SequencePathWords.also(running: other, in: [sequence()]) == nil
        )
    }

    @Test("KiwiHub lists an end key by its path, the leader not at all")
    func referenceListsPaths() {
        LocalizationManager.shared.select("en")
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: "default", bindings: [sequence()]),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: ["default"]
        )
        let rows = reference.controls.flatMap(\.rows) + reference.custom
        let path = SequencePathWords.drawn(["ctrl+alt+space", "w", "h"])
        #expect(
            rows.contains {
                $0.combo == path && $0.label == left.resolvedLabel
            }
        )
        #expect(rows.count == 1)
    }

    @Test("a layer rename and delete reach a sequence's end keys")
    func layerRewritesReachEndKeys() {
        let to = KeybindingCatalog.switchLayerCommand("Gaming").lua
        let layers = [
            KeyLayer(name: "default", bindings: [sequence(endLua: to)]),
            KeyLayer(name: "Gaming"),
        ]
        let renamed = KeybindingCatalog.renameLayer(
            in: layers,
            from: "Gaming",
            to: "Play"
        )
        let ends = renamed[0].sequences.flatMap(\.endKeys)
            .map(\.binding.lua).filter { !$0.isEmpty }
        #expect(ends == [KeybindingCatalog.switchLayerCommand("Play").lua])
        let deleted = KeybindingCatalog.deleteLayer(
            in: layers,
            named: "Gaming"
        )
        #expect(
            !deleted[0].sequences.flatMap(\.endKeys)
                .contains { $0.binding.lua == to }
        )
        #expect(deleted[0].sequences.count == 1)
    }
}
