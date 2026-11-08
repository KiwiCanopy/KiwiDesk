import Foundation
import Testing

@testable import KiwiDeskCore

/// The readers of a layer's flat rows treat a sequence as one unit,
/// and those that ask what an action does reach its end keys
/// (#1871).
@Suite("Key sequence readers")
struct KeySequenceReaderTests {
    static let goToTwo = KeyBinding.sequence(
        combo: "ctrl+alt+space",
        label: "Leader",
        steps: [
            KeyBinding(combo: "2", lua: "KiwiDesk.focus_space(\"2\")"),
            KeyBinding(combo: "3", lua: "KiwiDesk.focus_space(\"3\")"),
        ]
    )

    @Test("A re-import replaces a sequence whole, its id kept")
    func mergeReplacesWhole() {
        var config = GuiConfig()
        let stored = KeySequenceStorageTests.windows
        config.layers = [KeyLayer(name: "default", bindings: [stored])]
        KeybindingMerge.merge(
            recovered: [KeyLayer(name: "default", bindings: [Self.goToTwo])],
            into: &config
        )
        let row = config.layers[0].bindings
        #expect(row.count == 1)
        #expect(row.first == Self.goToTwo)
        #expect(row.first?.id == stored.id)
    }

    @Test("A Space rename reaches the end keys")
    func renameReachesEndKeys() {
        var config = GuiConfig()
        config.spaces = [SpaceID("2")]
        config.layers = [KeyLayer(name: "default", bindings: [Self.goToTwo])]
        config.renameSpace(from: SpaceID("2"), to: SpaceID("Mail"))
        #expect(
            config.layers[0].bindings[0].steps?.first?.lua
                == "KiwiDesk.focus_space(\"Mail\")"
        )
    }

    @Test("A gone Space takes its end key and leaves the leader")
    func spaceDropTrimsTheSequence() throws {
        let layers = [KeyLayer(name: "default", bindings: [Self.goToTwo])]
        let result = layers.removingRows(naming: [SpaceID("2")])
        let kept = try #require(result.layers[0].sequences.first)
        #expect(kept.steps?.map(\.combo) == ["3"])
        // No row was taken, so no tombstone combo is named.
        #expect(result.removed.isEmpty)
    }

    @Test("A sequence names the Spaces its end keys name")
    func sequenceNames() {
        #expect(Self.goToTwo.names([SpaceID("3")]))
        #expect(!Self.goToTwo.names([SpaceID("9")]))
    }

    @Test("A profile override holds or diffs a sequence whole")
    func overrideIsWhole() {
        let base = [KeyLayer(name: "default", bindings: [Self.goToTwo])]
        var edited = base
        edited[0].bindings[0].steps?.removeLast()
        let diff = KeyLayerOverride.diff(base: base, edited: edited)
        #expect(diff?.layers.first?.bindings == [edited[0].bindings[0]])
        #expect(diff?.resolved(onto: base) == edited)
        #expect(KeyLayerOverride.diff(base: base, edited: base) == nil)
    }

    @Test("A changed step is a write the save sees")
    func shapeSeesSteps() {
        let base = [KeyLayer(name: "default", bindings: [Self.goToTwo])]
        var edited = base
        edited[0].bindings[0].steps?[0].combo = "4"
        #expect(!RuleReachTable<String>.sameShortcuts(base, edited))
        var renamed = base
        renamed[0].bindings[0].label = "Other"
        #expect(!RuleReachTable<String>.sameShortcuts(base, renamed))
        #expect(RuleReachTable<String>.sameShortcuts(base, base))
    }

    @Test("A leader is conflict-checked against a row on its chord")
    func leaderConflicts() {
        let row = KeyBinding(combo: "ctrl+alt+space", lua: "x()")
        let conflicts = KeybindingConflicts.conflicts(
            in: [KeyLayer(name: "default", bindings: [row, Self.goToTwo])],
            distinguishingSides: false
        )
        #expect(conflicts.count == 2)
    }
}
