import Foundation
import Testing

@testable import KiwiDeskCore

/// `shortcut.remove_sequence` (#3124 ▸ Ruling 4): a whole key
/// sequence goes by its leader, at `shortcut.remove`'s reach, and
/// `shortcut.remove` refuses a leader by naming that verb.
@Suite("Shortcut sequence commands (#3124)", .serialized)
@MainActor
struct ShortcutSequenceCommandsTests {
    private let leader = "ctrl+alt+space"

    private func tree() -> KeyBinding {
        .sequence(
            combo: leader,
            label: "Leader",
            steps: [
                KeyBinding(
                    combo: "h",
                    lua: "KiwiDesk.focus(\"left\")",
                    kind: .navigation
                )
            ]
        )
    }

    private func core() throws -> KiwiCore {
        let core = try KeepFixture.core()
        var config = try #require(core.guiConfigStore.load())
        if let at = config.layers.firstIndex(where: \.isDefault) {
            config.layers[at].bindings.append(tree())
        } else {
            config.layers.append(
                KeyLayer(name: KeyLayer.defaultName, bindings: [tree()])
            )
        }
        try core.guiConfigStore.save(config)
        return core
    }

    private func sequences(_ core: KiwiCore) -> [KeyBinding] {
        core.guiConfigStore.load()?.layers.first(where: \.isDefault)?
            .sequences ?? []
    }

    @Test("remove refuses a leader and names the sequence verb")
    func removeNamesTheVerb() throws {
        let core = try core()
        let refused = core.execute(
            "shortcut.remove",
            args: [.string(leader)]
        )
        #expect(!refused.isSuccess)
        #expect(
            refused.error
                == "control+option+space opens a key sequence; use "
                + "shortcut.remove_sequence"
        )
        #expect(sequences(core) == [tree()])
    }

    @Test("remove_sequence takes the whole tree and refuses a free chord")
    func removeSequenceTakesTheTree() throws {
        let core = try core()
        #expect(
            core.execute(
                "shortcut.remove_sequence",
                args: [.string(leader)]
            ).isSuccess
        )
        #expect(sequences(core).isEmpty)
        #expect(
            !core.execute(
                "shortcut.remove_sequence",
                args: [.string(leader)]
            ).isSuccess
        )
    }

    @Test("remove_sequence is a destructive setting")
    func registered() {
        #expect(APIReference.destructive.contains("shortcut.remove_sequence"))
    }
}
