import Foundation
import Testing

@testable import KiwiDeskCore

/// The top-ups' offer travels with the setup (#2324): a second Mac
/// sharing the config folder never re-adds a row the user deleted
/// on the first, a pre-#2324 Mac's own marks cross into the file
/// once, and no writer lowers what the file records.
@Suite("The shortcut offer travels with the setup", .serialized)
@MainActor
struct ShortcutOfferTests {
    private func folder() -> URL {
        testTemporaryDirectory.appendingPathComponent(
            "kiwi-offer-\(UUID().uuidString)"
        )
    }

    /// A Mac reading `directory`, with no pre-#2324 marks.
    private func mac(_ directory: URL) -> KiwiCore {
        let core = makeTestCore(configDirectory: directory)
        core.desktopMemory.readLegacyShortcutOffer = { nil }
        return core
    }

    private func offered(_ core: KiwiCore) -> ShortcutOffer? {
        core.persistedGuiConfig()?.shortcutOffer
    }

    private func baseLua(_ core: KiwiCore) -> [String] {
        (core.persistedGuiConfig()?.layers.first { $0.isDefault }?
            .bindings ?? []).map(\.lua)
    }

    private func delete(_ lua: String, in core: KiwiCore) throws {
        var config = try #require(core.persistedGuiConfig())
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings.removeAll { $0.lua == lua }
        try core.guiConfigStore.save(config)
    }

    @Test("A row deleted on one Mac is not re-added by another")
    func deletedStaysDeletedAcrossMacs() throws {
        let shared = folder()
        let first = mac(shared)
        try first.guiConfigStore.save(GuiConfig())
        first.topUpDesktopShortcuts(desktops: [1, 2, 3])
        first.topUpGenerationShortcuts()
        let desktop2 = "KiwiDesk.focus_desktop(2)"
        let generationRow = try #require(
            DefaultKeybindings.rows(
                ofGeneration: DefaultKeybindings.newestGeneration
            ).first?.lua
        )
        #expect(baseLua(first).contains(generationRow))
        try delete(desktop2, in: first)
        try delete(generationRow, in: first)

        let second = mac(shared)
        second.topUpDesktopShortcuts(desktops: [1, 2, 3, 4])
        second.topUpGenerationShortcuts()
        #expect(!baseLua(second).contains(desktop2))
        #expect(!baseLua(second).contains(generationRow))
        #expect(baseLua(second).contains("KiwiDesk.focus_desktop(4)"))
        #expect(offered(second)?.desktop == 4)
    }

    @Test("This Mac's pre-#2324 marks cross into the file once")
    func legacyMarksCross() throws {
        let core = makeTestCore(configDirectory: folder())
        try core.guiConfigStore.save(GuiConfig())
        var legacy: ShortcutOffer? = ShortcutOffer(
            desktop: 5,
            generation: DefaultKeybindings.newestGeneration
        )
        core.desktopMemory.readLegacyShortcutOffer = { legacy }
        core.desktopMemory.clearLegacyShortcutOffer = { legacy = nil }
        core.crossLegacyShortcutOffer()
        #expect(legacy == nil)
        #expect(
            offered(core)
                == ShortcutOffer(
                    desktop: 5,
                    generation: DefaultKeybindings.newestGeneration
                )
        )
        // The crossed marks still answer: nothing is offered again.
        let before = baseLua(core)
        core.topUpDesktopShortcuts(desktops: [1, 2, 3])
        core.topUpGenerationShortcuts()
        #expect(baseLua(core) == before)
    }

    @Test("Uncrossed marks still raise what the file records")
    func legacyRaisesTheRead() throws {
        let core = makeTestCore(configDirectory: folder())
        var stored = GuiConfig()
        stored.shortcutOffer = ShortcutOffer(desktop: 1)
        try core.guiConfigStore.save(stored)
        core.desktopMemory.readLegacyShortcutOffer = {
            ShortcutOffer(desktop: 3)
        }
        core.desktopMemory.clearLegacyShortcutOffer = {}
        core.topUpDesktopShortcuts(desktops: [1, 2, 3])
        #expect(!baseLua(core).contains("KiwiDesk.focus_desktop(2)"))
    }

    @Test("A write never lowers the offer the file records")
    func writeNeverLowers() throws {
        let core = mac(folder())
        var stored = GuiConfig()
        stored.shortcutOffer = ShortcutOffer(desktop: 5, generation: 3)
        try core.guiConfigStore.save(stored)
        var stale = GuiConfig()
        stale.shortcutOffer = ShortcutOffer(desktop: 2, generation: 4)
        try core.guiConfigStore.save(stale)
        #expect(offered(core) == ShortcutOffer(desktop: 5, generation: 4))
        try core.guiConfigStore.save(GuiConfig())
        #expect(offered(core) == ShortcutOffer(desktop: 5, generation: 4))
    }

    @Test("gui.json carries the offer under its key")
    func storedShape() throws {
        var config = GuiConfig()
        config.shortcutOffer = ShortcutOffer(desktop: 2, generation: 1)
        let root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(config)
            ) as? [String: Any]
        )
        let offer = try #require(root["shortcut_offer"] as? [String: Int])
        #expect(offer == ["desktop": 2, "generation": 1])
        #expect(
            try JSONDecoder().decode(GuiConfig.self, from: Data("{}".utf8))
                .shortcutOffer == nil
        )
    }
}
