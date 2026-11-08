import Foundation
import Testing

@testable import KiwiDeskCore

/// A key sequence's stored shape (#1871 ▸ storage and step keys).
@Suite("Key sequence storage")
struct KeySequenceStorageTests {
    static let windows = KeyBinding.sequence(
        combo: "ctrl+alt+space",
        label: "Leader",
        steps: [
            .sequence(
                combo: "w",
                label: "Windows",
                steps: [
                    KeyBinding(combo: "h", lua: "KiwiDesk.focus(\"left\")"),
                    KeyBinding(combo: "l", lua: "KiwiDesk.focus(\"right\")"),
                ]
            ),
            KeyBinding(combo: "t", lua: "KiwiDesk.toggle_float()"),
        ]
    )

    private func roundTrip(_ binding: KeyBinding) throws -> KeyBinding {
        try JSONDecoder().decode(
            KeyBinding.self,
            from: JSONEncoder().encode(binding)
        )
    }

    private func decode(_ json: String) throws -> KeyBinding {
        try JSONDecoder().decode(KeyBinding.self, from: Data(json.utf8))
    }

    @Test("A sequence round-trips whole, its tree nested")
    func roundTrips() throws {
        let back = try roundTrip(Self.windows)
        #expect(back == Self.windows)
        #expect(back.steps?.first?.steps?.count == 2)
    }

    @Test("A press row writes no steps key")
    func pressRowIsSparse() throws {
        let data = try JSONEncoder().encode(
            KeyBinding(combo: "alt+h", lua: "x()")
        )
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("steps"))
    }

    @Test("A sequence without steps is refused")
    func sequenceNeedsSteps() {
        #expect(throws: DecodingError.self) {
            try decode(#"{"combo":"a","lua":"","kind":"sequence"}"#)
        }
    }

    @Test("Steps on a press row are refused")
    func stepsNeedASequence() {
        #expect(throws: DecodingError.self) {
            try decode(
                #"{"combo":"a","lua":"x()","kind":"custom","steps":[]}"#
            )
        }
    }

    @Test("A sequence with an empty tree decodes")
    func emptyTreeDecodes() throws {
        let row = try decode(
            #"{"combo":"a","lua":"","kind":"sequence","steps":[]}"#
        )
        #expect(row.isSequence && row.steps == [])
    }

    @Test("Equality reads the steps")
    func equalityReadsSteps() {
        var other = Self.windows
        other.steps?[1].lua = "y()"
        #expect(other != Self.windows)
    }

    @Test("A sequence's sameAction compares it whole, name included")
    func sameActionIsWhole() {
        var renamed = Self.windows
        renamed.label = "Other"
        #expect(!renamed.sameAction(as: Self.windows))
        var stepped = Self.windows
        stepped.steps?.removeLast()
        #expect(!stepped.sameAction(as: Self.windows))
        #expect(Self.windows.sameAction(as: Self.windows))
        // A press row's identity stays combo and Lua.
        let row = KeyBinding(combo: "a", lua: "x()", label: "A")
        var relabelled = row
        relabelled.label = "B"
        #expect(row.sameAction(as: relabelled))
    }

    @Test("End keys walk depth first with their whole path")
    func endKeysWalk() {
        #expect(
            Self.windows.endKeys.map(\.path) == [
                ["ctrl+alt+space", "w", "h"],
                ["ctrl+alt+space", "w", "l"],
                ["ctrl+alt+space", "t"],
            ]
        )
    }

    @Test("A layer partitions its press rows from its sequences")
    func layerPartition() {
        let press = KeyBinding(combo: "alt+h", lua: "x()")
        let layer = KeyLayer(name: "default", bindings: [press, Self.windows])
        #expect(layer.pressBindings == [press])
        #expect(layer.sequences == [Self.windows])
        #expect(layer.actionBindings.map(\.combo) == ["alt+h", "h", "l", "t"])
    }

    @Test("Mapping actions reaches end keys and drops them on nil")
    func mappingActions() {
        let layer = KeyLayer(name: "default", bindings: [Self.windows])
        let mapped = layer.mappingActions {
            $0.combo == "h" ? nil : $0
        }
        #expect(mapped.bindings[0].steps?[0].steps?.map(\.combo) == ["l"])
        #expect(mapped.bindings[0].label == "Leader")
    }

    /// The floors the #1871 bump set: an older build refuses a
    /// file holding a sequence as newer, never as corrupt. A later
    /// bump keeps them; dropping one reds.
    @Test("Every format the ruling names is at least its bump")
    func formatsAreBumped() {
        #expect(GuiConfig.currentFormat >= 20)
        #expect(Profile.currentFormat >= 35)
        #expect(SetupBundle.currentFormat >= 44)
    }

    @Test("A gui.json carrying a sequence round-trips")
    func guiConfigCarriesIt() throws {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: [Self.windows])
        ]
        let back = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONEncoder().encode(config)
        )
        #expect(back.layers.first?.sequences == [Self.windows])
    }
}
