import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop tier's seed: `⌃⌥⇧⌘` + digit goes to that Desktop,
/// topped up for each Desktop past the setup's offer (#2324), so a
/// row the user deleted is never added back.
@Suite("Desktop shortcuts are topped up past the mark", .serialized)
@MainActor
struct DesktopShortcutTopUpTests {
    private let hyper = "control+option+shift+command+"

    private func lua(_ number: Int) -> String {
        "KiwiDesk.focus_desktop(\(number))"
    }

    @Test("A Desktop past the mark gets its row, 10 on the 0 key")
    func rowsPastTheMark() {
        let rows = DefaultKeybindings.desktopTopUp(
            existing: [],
            desktops: [1, 2, 3, 10, 11],
            above: 1
        )
        #expect(rows.map(\.lua) == [lua(2), lua(3), lua(10)])
        #expect(rows.map(\.combo) == ["2", "3", "0"].map { hyper + $0 })
        #expect(rows.allSatisfy { $0.kind == .navigation })
    }

    @Test("A bound Desktop or a taken chord is left alone")
    func boundOrTakenIsSkipped() {
        let existing = [
            KeyBinding(combo: "alt+2", lua: lua(2), kind: .navigation),
            KeyBinding(
                combo: hyper + "3",
                lua: "KiwiDesk.reload_config()",
                kind: .custom
            ),
        ]
        let rows = DefaultKeybindings.desktopTopUp(
            existing: existing,
            desktops: [1, 2, 3],
            above: 0
        )
        #expect(rows.map(\.lua) == [lua(1)])
    }

    private func offered(_ core: KiwiCore) -> ShortcutOffer {
        core.persistedGuiConfig()?.shortcutOffer ?? ShortcutOffer()
    }

    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-desktop-topup-\(UUID().uuidString)"
                )
        )
        try core.guiConfigStore.save(GuiConfig())
        core.desktopMemory.readLegacyShortcutOffer = { nil }
        return core
    }

    private func desktopRows(_ core: KiwiCore) -> [String] {
        (core.persistedGuiConfig()?.layers.first { $0.isDefault }?
            .bindings ?? [])
            .map(\.lua).filter { $0.hasPrefix("KiwiDesk.focus_desktop(") }
    }

    @Test("Each Desktop is offered once, and a deleted row stays gone")
    func offeredOnce() throws {
        let core = try makeCore()
        core.topUpDesktopShortcuts(desktops: [1, 2, 3])
        #expect(desktopRows(core) == [lua(1), lua(2), lua(3)])
        #expect(offered(core).desktop == 3)

        var config = try #require(core.persistedGuiConfig())
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings.removeAll { $0.lua == lua(2) }
        try core.guiConfigStore.save(config)

        core.topUpDesktopShortcuts(desktops: [1, 2, 3, 4])
        #expect(desktopRows(core) == [lua(1), lua(3), lua(4)])
        #expect(offered(core).desktop == 4)
    }

    @Test("A setup the GUI does not manage keeps its marks")
    func luaOwnedKeepsTheMark() throws {
        var cleared = 0
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-desktop-topup-lua-\(UUID().uuidString)"
                )
        )
        core.desktopMemory.readLegacyShortcutOffer = { ShortcutOffer() }
        core.desktopMemory.clearLegacyShortcutOffer = { cleared += 1 }
        #expect(!core.isGuiManaged)
        core.topUpDesktopShortcuts(desktops: [1, 2])
        core.crossLegacyShortcutOffer()
        #expect(cleared == 0)
        #expect(!core.guiConfigStore.exists)
    }

    @Test("Discarding gui.json offers every Desktop again")
    func discardClearsTheMark() throws {
        let core = try makeCore()
        var cleared = 0
        core.desktopMemory.clearLegacyShortcutOffer = { cleared += 1 }
        core.topUpDesktopShortcuts(desktops: [1, 2])
        #expect(offered(core).desktop == 2)
        cleared = 0
        _ = core.discardArtifacts(
            [.guiConfig],
            reason: "test",
            trash: { try FileManager.default.removeItem(at: $0) }
        )
        #expect(cleared == 1)
        #expect(core.desktopMemory.knownShortcutOffer == nil)
        try core.guiConfigStore.save(GuiConfig())
        core.topUpDesktopShortcuts(desktops: [1, 2])
        #expect(desktopRows(core) == [lua(1), lua(2)])
    }

    @Test("A declining setup is asked once a session")
    func declineIsLatched() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-desktop-topup-latch-\(UUID().uuidString)"
                )
        )
        core.desktopMemory.readLegacyShortcutOffer = { nil }
        core.topUpDesktopShortcuts(desktops: [1, 2])
        #expect(core.desktopMemory.shortcutTopUpDeclined == 2)
        // Managed now, but the session already declined these.
        try core.guiConfigStore.save(GuiConfig())
        core.topUpDesktopShortcuts(desktops: [1, 2])
        #expect(core.persistedGuiConfig()?.shortcutOffer == nil)
    }
}
