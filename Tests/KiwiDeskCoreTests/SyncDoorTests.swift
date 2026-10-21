import Foundation
import Testing

@testable import KiwiDeskCore

/// The door a synced change enters by writes no synced file
/// (#2324): every machine event that rewrites the shared setup —
/// the three top-ups, the legacy offer's crossing, the Space-list
/// mirror and a gone Space's shortcut drop — stands down while it
/// is open, so two
/// Macs never answer each other's change with one of their own.
@Suite("A synced change is answered with no write", .serialized)
@MainActor
struct SyncDoorTests {
    /// A GUI-managed core every top-up would write into: no offer
    /// recorded, Spaces without digit rows, a new Desktop.
    private func eagerCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-sync-door-\(UUID().uuidString)")
        )
        core.onLog = { _ in }
        var config = GuiConfig()
        let index = try #require(config.layers.firstIndex { $0.isDefault })
        config.layers[index].bindings = []
        try core.guiConfigStore.save(config)
        core.desktopMemory.readLegacyShortcutOffer = { ShortcutOffer() }
        core.desktopMemory.clearLegacyShortcutOffer = {}
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        return core
    }

    private func gui(_ core: KiwiCore) -> Data? {
        try? Data(contentsOf: core.url(of: .guiConfig))
    }

    private func runEveryWriter(_ core: KiwiCore) {
        core.crossLegacyShortcutOffer()
        core.topUpDesktopShortcuts(desktops: [1, 2])
        core.topUpGenerationShortcuts()
        core.topUpDigitShortcuts()
        core.syncGuiSpacesToLive()
    }

    @Test("Each writer writes outside the door")
    func writersWriteOutside() throws {
        let core = try eagerCore()
        let before = gui(core)
        runEveryWriter(core)
        #expect(gui(core) != before)
    }

    @Test("No writer writes inside the door")
    func writersStandDownInside() throws {
        let core = try eagerCore()
        let before = gui(core)
        core.sync.adopting = 1
        runEveryWriter(core)
        #expect(gui(core) == before)
        core.sync.adopting = 0
    }

    @Test("Each writer stands down alone")
    func eachStandsDown() throws {
        let writers: [@MainActor (KiwiCore) -> Void] = [
            { $0.crossLegacyShortcutOffer() },
            { $0.topUpDesktopShortcuts(desktops: [1, 2]) },
            { $0.topUpGenerationShortcuts() },
            { $0.topUpDigitShortcuts() },
            { $0.syncGuiSpacesToLive() },
        ]
        for writer in writers {
            let inside = try eagerCore()
            let before = gui(inside)
            inside.sync.adopting = 1
            writer(inside)
            #expect(gui(inside) == before)
            let outside = try eagerCore()
            let untouched = gui(outside)
            writer(outside)
            #expect(gui(outside) != untouched)
        }
    }

    @Test("A gone Space's shortcut drop waits for the door to close")
    func dropWaits() throws {
        let core = try eagerCore()
        core.state.owedShortcutDrops = [SpaceID("9")]
        core.sync.adopting = 1
        core.payOwedShortcutDrops()
        #expect(core.state.owedShortcutDrops == [SpaceID("9")])
        core.sync.adopting = 0
        core.payOwedShortcutDrops()
        #expect(core.state.owedShortcutDrops.isEmpty)
    }

    @Test("The door is open for the reload and closed after")
    func doorWrapsTheReload() throws {
        let core = try eagerCore()
        var seen: [Int] = []
        core.sync.onSyncedIn = { [weak core] _ in
            seen.append(core?.sync.adopting ?? -1)
        }
        core.adoptSyncedChange(SyncedChange(paths: ["gui.json"], mac: nil))
        #expect(seen == [1])
        #expect(core.sync.adopting == 0)
    }
}
