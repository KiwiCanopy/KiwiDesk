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
        // The leader branch and its refusal, as one span.
        #expect(
            row.filter { !$0.isWhitespace }.contains(
                "ifisLeader{guard!KeyBinding.admitsLeader(node.combo)"
                    + "else{returnnil}"
            )
        )
    }

    @Test("the recorder's sibling check is Core's (#3174)")
    func siblingRuleIsCores() throws {
        let tree = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Keybindings/"
                        + "Sequences/SequenceTree.swift"
                )
        )
        #expect(tree.contains("KeyBinding.stepKey("))
        #expect(!tree.contains("KeyCombo.equivalent"))
        // The node being recorded is never its own sibling.
        let own = KeyBinding(combo: "w", lua: "x")
        let other = KeyBinding(combo: "h", lua: "y")
        let root = KeyBinding.sequence(
            combo: "ctrl+alt+space",
            steps: [own, other]
        )
        #expect(
            SequenceTree.sibling(holding: "w", besides: own.id, in: root)
                == nil
        )
        #expect(
            SequenceTree.sibling(holding: "w", besides: other.id, in: root)?
                .id == own.id
        )
    }

    @Test("the leader's row carries the sequence's reach (#3124)")
    func leaderRowCarriesReach() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/Sequences"
            )
        let row = try SourceScan.strippedSource(
            at: dir.appendingPathComponent("SequenceNodeRow.swift")
        )
        let recorder = try SourceScan.strippedSource(
            at: dir.appendingPathComponent("SequenceNodeRow+Recorder.swift")
        )
        let flat = row.filter { !$0.isWhitespace }
        // The leader's line alone carries reach and its trash; a
        // step key's line ends in a plain remove (#3162).
        #expect(flat.contains("ifisLeader{leaderLine}else{keyLine}"))
        let leader = try #require(
            SourceScan.declarationBody(
                after: "private var leaderLine",
                in: row
            )
        ).filter { !$0.isWhitespace }
        #expect(
            leader.contains(
                "KeyReachColumn(model:model,layer:layerName,binding:node)"
                    + "recorderKeyReachTrash(model:model,layer:layerName,"
                    + "binding:node){requestDelete()}"
            )
        )
        let key = try #require(
            SourceScan.declarationBody(after: "private var keyLine", in: row)
        )
        #expect(!key.contains("KeyReach"))
        let carry = recorder.filter { !$0.isWhitespace }
        #expect(
            carry.contains(
                "ifisLeader{model.carrySequenceReach(layer:layerName,"
                    + "from:node.combo,to:combo)}editing.update(node.id)"
            )
        )
        let card = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Sections/KeySequencesCard.swift"
                )
        )
        #expect(!card.isEmpty)
        #expect(!card.contains(".disabled("))
    }

    @Test("the Also caption's spoken twin is the spoken path")
    func alsoIsSpoken() throws {
        let nav = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Keybindings/"
                        + "KeybindingNavRow.swift"
                )
        )
        .filter { !$0.isWhitespace }
        #expect(
            nav.contains(
                "alsoSpoken:SequencePathWords.also(running:command,"
                    + "in:rows,spoken:true)"
            )
        )
        #expect(nav.contains(".accessibilityLabel(drawn.alsoSpoken??also)"))
        // A path hit is drawn on its row (#1871).
        let bands = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Shortcuts/ShortcutsBands.swift"
                )
        )
        .filter { !$0.isWhitespace }
        #expect(bands.contains("ifletdetail=row.detail??pathHit{"))
    }

    @Test("a long path shortens to its leader and last two keys")
    func longPathShortens() {
        let short = ["ctrl+alt+space", "w", "h"]
        #expect(
            SequencePathWords.shortened(short)
                == SequencePathWords.drawn(short)
        )
        let four = ["ctrl+alt+space", "w", "s", "2"]
        #expect(
            SequencePathWords.shortened(four) == SequencePathWords.drawn(four)
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
        // A key one step deeper is a different tree.
        var lifted = base
        lifted.bindings[0].steps?[0].steps?.append(
            KeyBinding(combo: "t", lua: left.lua, kind: .navigation)
        )
        #expect(!SettingsModel.sameRows(grown, lifted))
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
