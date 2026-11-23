import Foundation
import Testing

@testable import KiwiDeskCore

/// The areas' Desktop memory outlives the process beside the
/// Desktop cursor (#3517 ruling 17): in `machine.json`, never in
/// `gui.json`, identity-keyed entries alone, stamped from the
/// session at every write and adopted at a load.
@Suite("Desktop memory per area persistence (#3517)")
@MainActor
struct AreaDesktopMemoryPersistenceTests {
    private let stamp = DesktopIdentity(raw: "AREA-M")

    private func scratch() -> URL {
        testTemporaryDirectory
            .appendingPathComponent("kiwi-area-mem-\(UUID().uuidString)")
    }

    private func root(_ url: URL) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
    }

    private var shown: [String: SpaceID] {
        ["Wide#1": SpaceID("2")]
    }

    @Test("machine.json carries the identity entries alone")
    func machineFileCarriesIdentities() throws {
        let dir = scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GuiConfigStore(
            directory: dir,
            machine: dir.appendingPathComponent("machine")
        )
        var config = GuiConfig()
        config.desktopAreaSpaces = [
            .identity(stamp): shown, .number(4): shown,
        ]
        try store.save(config)
        #expect(try root(store.url)["desktop_area_spaces"] == nil)
        #expect(
            try root(store.machine.url)["desktop_area_spaces"] != nil
        )
        #expect(
            store.load()?.desktopAreaSpaces == [.identity(stamp): shown]
        )
    }

    @Test("an empty memory writes no key")
    func emptyWritesNoKey() throws {
        let data = try JSONEncoder().encode(MachineConfig())
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("desktop_area_spaces"))
    }

    @Test("every write stamps the session's areas' memory")
    func writeStampsTheSession() throws {
        let dir = scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        var store = GuiConfigStore(
            directory: dir,
            machine: dir.appendingPathComponent("machine")
        )
        store.liveDesktopSpaces = [:]
        store.liveDesktopAreaSpaces = [.identity(stamp): shown]
        try store.save(GuiConfig())
        #expect(
            store.load()?.desktopAreaSpaces == [.identity(stamp): shown]
        )
        store.liveDesktopAreaSpaces = [:]
        try store.saveMachineLocal()
        #expect(store.load()?.desktopAreaSpaces == [:])
    }

    @Test("a load adopts the stored areas' memory")
    func loadAdopts() {
        let core = makeTestCore()
        core.adoptPersistedDesktopSpaces(
            [:],
            areas: [.identity(stamp): shown]
        )
        #expect(
            core.desktopMemory.areaSpaces == [.identity(stamp): shown]
        )
        #expect(
            core.persistedDesktopAreaSpaces()
                == [.identity(stamp): shown]
        )
    }

    @Test("the core's store stamps the session's areas' memory")
    func coreStampsTheStore() {
        let core = makeTestCore()
        core.adoptPersistedDesktopSpaces(
            [:],
            areas: [.identity(stamp): shown]
        )
        #expect(
            core.guiConfigStore.liveDesktopAreaSpaces
                == [.identity(stamp): shown]
        )
    }

    @Test("structured rules hand the stored map to the adoption")
    func structuredRulesAdopt() {
        let core = makeTestCore()
        var config = GuiConfig()
        config.desktopAreaSpaces = [.identity(stamp): shown]
        core.applyStructuredRules(from: config)
        #expect(
            core.desktopMemory.areaSpaces == [.identity(stamp): shown]
        )
    }

    @Test("a merge moves the vanished area's entry to the survivor")
    func mergeMovesTheEntry() {
        var config = GuiConfig()
        config.desktopAreaSpaces = [
            .identity(stamp): ["Wide#2": SpaceID("5")]
        ]
        config.apply(
            ScreenAreaRemap(
                vanished: ScreenAreaKey(fingerprint: "Wide", areaID: 2),
                survivor: ScreenAreaKey(fingerprint: "Wide", areaID: 1)
            )
        )
        #expect(
            config.desktopAreaSpaces[.identity(stamp)]
                == ["Wide#1": SpaceID("5")]
        )
    }
}
