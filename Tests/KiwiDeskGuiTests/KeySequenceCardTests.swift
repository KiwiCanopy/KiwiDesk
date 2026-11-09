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
        #expect(gone.steps?.first?.steps?.count == 1)
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
        var root = sequence()
        root.steps?.append(
            KeyBinding(
                combo: "t",
                lua: "print(1)",
                kind: .custom,
                desc: "Mine"
            )
        )
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: "default", bindings: [root]),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: ["default"]
        )
        let rows =
            reference.controls.flatMap(\.rows) + reference.custom
            + reference.groups.flatMap(\.rows)
        let path = SequencePathWords.drawn(["ctrl+alt+space", "w", "h"])
        #expect(
            rows.contains {
                $0.combo == path && $0.label == left.resolvedLabel
            }
        )
        // The user's Lua end key is listed by path too, never dropped.
        let lua = SequencePathWords.drawn(["ctrl+alt+space", "t"])
        #expect(rows.contains { $0.combo == lua && $0.label == "Mine" })
        #expect(rows.count == 2)
    }

    @Test("a step key the router never matches is told apart")
    func admitsAsTheRouter() throws {
        let leader = "ctrl+alt+space"
        #expect(KeyBinding.admitsStepKey("w", under: leader))
        #expect(KeyBinding.admitsStepKey("ctrl+alt+w", under: leader))
        #expect(!KeyBinding.admitsStepKey("escape", under: leader))
        #expect(!KeyBinding.admitsStepKey("delete", under: leader))
        #expect(!KeyBinding.admitsStepKey("cmd+cmd", under: leader))
        #expect(!KeyBinding.admitsStepKey(leader, under: leader))
        #expect(KeyBinding.admitsLeader(leader))
        #expect(!KeyBinding.admitsLeader("hyper+a"))
        // The row asks Core first, against its own leader.
        let row = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Keybindings/"
                        + "Sequences/SequenceNodeRow+Recorder.swift"
                )
        )
        #expect(row.contains("if let refused = refusal { return refused }"))
        #expect(
            row.contains(
                "KeyBinding.admitsStepKey(node.combo, under: leader)"
            )
        )
        #expect(row.contains("guard let leader = editing.root?.combo"))
    }

    @Test("the card greys on a stored profile's page (#3124)")
    func storedPageGreys() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/KeySequencesCard.swift"
            )
        let text = try SourceScan.strippedSource(at: file)
        #expect(!text.isEmpty)
        #expect(text.contains(".disabled(block != nil)"))
        #expect(text.contains("model.sequenceEditBlock(in: layerName)"))
    }

    @Test("a path row follows a folded run, which stays whole")
    func pathFollowsTheFold() {
        LocalizationManager.shared.select("en")
        let spaces = [SpaceID("1"), SpaceID("2"), SpaceID("3")]
        let go = KeybindingCatalog.goToSpace(spaces)
        var rows = go.enumerated().map { at, command in
            KeyBinding(
                combo: "ctrl+alt+\(at + 1)",
                lua: command.lua,
                kind: .navigation
            )
        }
        rows.append(
            .sequence(
                combo: "ctrl+alt+space",
                label: "Leader",
                steps: [
                    .sequence(
                        combo: "s",
                        label: "Spaces",
                        steps: [
                            KeyBinding(
                                combo: "2",
                                lua: go[1].lua,
                                kind: .navigation
                            )
                        ]
                    )
                ]
            )
        )
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: "default", bindings: rows),
            spaces: spaces,
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: ["default"]
        )
        let focus = reference.controls.flatMap(\.rows)
        let path = SequencePathWords.drawn(["ctrl+alt+space", "s", "2"])
        let folded = focus.firstIndex { !$0.members.isEmpty }
        let after = focus.firstIndex { $0.combo == path }
        #expect(folded != nil && after != nil)
        #expect(focus.filter { !$0.members.isEmpty }.count == 1)
        if let folded, let after { #expect(after == folded + 1) }
    }

    @Test("KiwiHub search finds a path row by a name along its path")
    func searchReadsPathNames() {
        LocalizationManager.shared.select("en")
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: "default", bindings: [sequence()]),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: ["default"]
        )
        var sheet = ShortcutsSheet(reference: reference)
        sheet.setQuery("windows")
        let rows = sheet.shown?.controls.flatMap(\.rows) ?? []
        #expect(rows.count == 1)
        #expect(rows.first?.detail?.contains("Windows") == true)
        sheet.setQuery("nowhere")
        #expect(sheet.matchCount == 0)
    }

    @Test("a long path shortens to its leader and last two keys")
    func longPathShortens() {
        let short = ["ctrl+alt+space", "w", "h"]
        #expect(
            SequencePathWords.shortened(short)
                == SequencePathWords.drawn(short)
        )
        let long = ["ctrl+alt+space", "w", "s", "2", "x"]
        let drawn = SequencePathWords.shortened(long)
        #expect(
            drawn
                == SequencePathWords.drawn(["ctrl+alt+space"]) + " \u{2192} "
                + "\u{2026} \u{2192} "
                + SequencePathWords.drawn(["2", "x"])
        )
    }

    @Test("two copies of a layer differ by a sequence's tree")
    func layerCompareReadsTheTree() {
        let base = KeyLayer(name: "default", bindings: [sequence()])
        var renamed = base
        renamed.bindings[0].steps?[0].label = "Win"
        var grown = base
        grown.bindings[0].steps?.append(
            KeyBinding(combo: "t", lua: left.lua, kind: .navigation)
        )
        var named = base
        named.bindings[0].label = "Other"
        #expect(SettingsModel.sameRows(base, base))
        #expect(!SettingsModel.sameRows(base, renamed))
        #expect(!SettingsModel.sameRows(base, grown))
        #expect(!SettingsModel.sameRows(base, named))
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
