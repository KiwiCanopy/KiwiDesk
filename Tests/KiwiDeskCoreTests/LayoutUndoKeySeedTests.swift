import Foundation
import Testing

@testable import KiwiDeskCore

/// The undo pair seeds on the key that types "z" on the active
/// layout, not on the US Z position (#3599): a German QWERTZ board
/// types "z" on key code 16, which `KeyCombo` spells `y`. Every
/// other default stays positional.
@Suite("Layout undo seeds by letter (#3599)", .serialized)
@MainActor
struct LayoutUndoKeySeedTests {
    /// A US board: each letter on its own `KeyCombo` name.
    private static let us: (String) -> UInt32? = { KeyCombo.keyCodes[$0] }
    /// German QWERTZ: Z and Y trade places.
    private static let qwertz: (String) -> UInt32? = {
        switch $0 {
        case "z": 16
        case "y": 6
        default: KeyCombo.keyCodes[$0]
        }
    }

    private let undo = "KiwiDesk.undo_layout()"
    private let redo = "KiwiDesk.redo_layout()"

    private func combo(_ lua: String, in rows: [KeyBinding]) -> String? {
        rows.first { $0.lua == lua }?.combo
    }

    @Test("the key name follows the letter, else the US position")
    func keyFollowsTheLetter() {
        #expect(
            DefaultKeybindings.layoutUndoKey(keyCodeTyping: Self.us) == "z"
        )
        #expect(
            DefaultKeybindings.layoutUndoKey(keyCodeTyping: Self.qwertz)
                == "y"
        )
        // No "z" on the layout, or not ASCII-capable: the US Z.
        #expect(
            DefaultKeybindings.layoutUndoKey(keyCodeTyping: { _ in nil })
                == "z"
        )
        // A code `KeyCombo` cannot name falls back to the US Z.
        #expect(
            DefaultKeybindings.layoutUndoKey(keyCodeTyping: { _ in 999 })
                == "z"
        )
        // So does one whose name parses to another code: keypad 1
        // (83) is named `1`, the number row's 18.
        #expect(
            DefaultKeybindings.layoutUndoKey(keyCodeTyping: { _ in 83 })
                == "z"
        )
    }

    @Test("the first-run seed puts undo and redo on the QWERTZ Z")
    func seedTakesTheKey() {
        let rows = DefaultKeybindings.bindings(
            spaces: [SpaceID("1")],
            resizeStep: 50,
            base: .standard,
            undoKey: "y"
        )
        #expect(combo(undo, in: rows) == "control+option+y")
        #expect(combo(redo, in: rows) == "control+option+shift+y")
        // No other seed row shares either chord.
        let chords = rows.compactMap { KeyCombo.parse($0.combo)?.registered }
        #expect(chords.count == Set(chords).count)
    }

    @Test("a key another seed row holds falls back to the US Z")
    func takenKeyFallsBack() {
        // ⌃⌥C is the next-layout row's.
        let rows = DefaultKeybindings.bindings(
            spaces: [SpaceID("1")],
            resizeStep: 50,
            base: .standard,
            undoKey: "c"
        )
        #expect(combo(undo, in: rows) == "control+option+z")
        #expect(combo(redo, in: rows) == "control+option+shift+z")
    }

    @Test("generation 15 offers the pair on the same key")
    func generationTakesTheKey() {
        let rows = DefaultKeybindings.rows(ofGeneration: 15, undoKey: "y")
        #expect(combo(undo, in: rows) == "control+option+y")
        #expect(combo(redo, in: rows) == "control+option+shift+y")
    }

    // The two Core writers read the seam, not the positional default.

    private func makeCore(
        layout: @escaping (String) -> UInt32?
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-undo-key-\(UUID().uuidString)"
                )
        )
        core.keyCodeTyping = layout
        return core
    }

    private func stored(_ core: KiwiCore) -> [KeyBinding] {
        core.persistedGuiConfig()?.layers.first { $0.isDefault }?
            .bindings ?? []
    }

    @Test("a fresh install seeds undo on the layout's Z")
    func firstRunReadsTheLayout() {
        let core = makeCore(layout: Self.qwertz)
        core.loadConfig()
        #expect(combo(undo, in: stored(core)) == "control+option+y")
        #expect(combo(redo, in: stored(core)) == "control+option+shift+y")
    }

    @Test("an upgrade's generation 15 lands on the layout's Z")
    func topUpReadsTheLayout() throws {
        let core = makeCore(layout: Self.qwertz)
        try core.guiConfigStore.save(GuiConfig())
        core.desktopMemory.readLegacyShortcutOffer = { nil }
        core.topUpGenerationShortcuts()
        #expect(combo(undo, in: stored(core)) == "control+option+y")
        #expect(combo(redo, in: stored(core)) == "control+option+shift+y")
    }

    @Test("an upgrade whose layout key is taken falls back to the US Z")
    func takenTopUpFallsBack() throws {
        let core = makeCore(layout: Self.qwertz)
        var config = GuiConfig()
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings = [
            KeyBinding(
                combo: "control+option+y",
                lua: "KiwiDesk.reload_config()",
                kind: .custom
            )
        ]
        try core.guiConfigStore.save(config)
        core.desktopMemory.readLegacyShortcutOffer = { nil }
        core.topUpGenerationShortcuts()
        #expect(combo(undo, in: stored(core)) == "control+option+z")
        #expect(combo(redo, in: stored(core)) == "control+option+shift+z")
    }

    @Test("an upgrade with undo already on the key adds redo beside it")
    func ownUndoKeepsThePair() throws {
        let core = makeCore(layout: Self.qwertz)
        var config = GuiConfig()
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings = [
            KeyBinding(
                combo: "control+option+y",
                lua: undo,
                kind: .navigation
            )
        ]
        try core.guiConfigStore.save(config)
        core.desktopMemory.readLegacyShortcutOffer = { nil }
        core.topUpGenerationShortcuts()
        #expect(combo(redo, in: stored(core)) == "control+option+shift+y")
    }

    @Test("the test core pins a US board over any layout")
    func pinIsUS() {
        let core = makeTestCore()
        core.keyCodeTyping = Self.qwertz
        pinDesktopReads(core)
        #expect(core.keyCodeTyping("z") == 6)
        #expect(core.layoutUndoKey == "z")
    }
}
