import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop bindings live in `bindings.json` on this Mac and
/// travel as the bundle's own field (#2324 rulings 10 and 12): a
/// `gui.json` of any older shape hands them over in the current
/// one, an old bundle's are lifted out of its `config`, and a
/// restore writes them into this Mac's file.
@MainActor
@Suite("Desktop bindings file (#2324)")
struct DesktopBindingsFileTests {
    private func scratch() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-bindings-\(UUID().uuidString)")
    }

    /// A format-1 `gui.json` still spells `"2": "Work"`; the carry
    /// reads the value every earlier step has rewritten, or the
    /// strip would delete a binding the carry could not decode.
    @Test("A format-1 gui.json hands its bindings over, rewritten")
    func oldShapeIsCarried() throws {
        let dir = scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = GuiConfigStore(
            directory: dir,
            machine: dir.appendingPathComponent("machine")
        )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        try Data(
            #"{"format":1,"spaces":["1"],"profile_bindings":{"2":"Work"}}"#
                .utf8
        ).write(to: store.url)
        let loaded = try #require(store.load())
        #expect(loaded.profileBindings[.number(2)]?.names == ["Work"])
        let gui = try #require(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: store.url)
            ) as? [String: Any]
        )
        #expect(gui["profile_bindings"] == nil)
        #expect(
            store.bindingsFile.load().profileBindings[.number(2)]?.names
                == ["Work"]
        )
    }

    @Test("An old bundle's bindings are lifted to the top level")
    func bundleLiftsBindings() throws {
        let bundle: [String: Any] = [
            "format": 28,
            "writtenBy": "test",
            "config": [
                "spaces": ["1"],
                "profile_bindings": [
                    "2": ["profiles": ["Work"], "desktop": 2]
                ],
            ],
            "profiles": [],
            "palettes": [],
        ]
        let data = try JSONSerialization.data(withJSONObject: bundle)
        let migrated = try #require(ConfigMigration.migrated(data))
        let decoded = try JSONDecoder().decode(
            SetupBundle.self,
            from: migrated
        )
        #expect(decoded.profileBindings?[.number(2)]?.names == ["Work"])
        #expect(decoded.config?.profileBindings.isEmpty == true)
    }

    /// The bindings travel with the backup and land in this Mac's
    /// file, keyed as the source wrote them.
    @Test("A restore writes the bundle's bindings")
    func restoreWritesBindings() throws {
        let source = makeTestCore()
        var config = GuiConfig()
        config.profileBindings = [
            .number(2): DesktopBinding(profile: "Away", desktop: 2)
        ]
        try source.guiConfigStore.save(config)
        let bundle = try source.exportSetup()
        #expect(bundle.profileBindings?[.number(2)]?.names == ["Away"])

        let target = makeTestCore()
        try target.guiConfigStore.save(GuiConfig())
        try target.restoreSetup(from: bundle) { url in
            try FileManager.default.removeItem(at: url)
        }
        #expect(
            target.guiConfigStore.bindingsFile.load()
                .profileBindings[.number(2)]?.names == ["Away"]
        )
    }
}
