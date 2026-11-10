import Foundation
import Testing

@testable import KiwiDeskCore

/// The checked-in test desk is what this build writes (#3121). A
/// `currentFormat` bump changes the stamp the stores write, so a
/// desk left behind reds here and names its regeneration. With
/// `KIWIDESK_REGEN_TEST_DESK=1` the suite rewrites the desk
/// instead (`scripts/test-desk regen`). No core boots, no window
/// server is read.
@Suite("Test desk fixture is current (#3121)")
struct TestDeskFixtureTests {
    private static let regen =
        ProcessInfo.processInfo.environment["KIWIDESK_REGEN_TEST_DESK"]
        == "1"
    private static let hint = "run scripts/test-desk regen"

    /// Every file the desk carries, relative to its config folder.
    private static func files(under root: URL) throws -> [String] {
        let walk = FileManager.default.enumerator(atPath: root.path)
        var found: [String] = []
        while let path = walk?.nextObject() as? String {
            var folder: ObjCBool = false
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent(path).path,
                isDirectory: &folder
            )
            if !folder.boolValue { found.append(path) }
        }
        return found.sorted()
    }

    @MainActor
    private static func fresh() throws -> URL {
        let base = testTemporaryDirectory.appendingPathComponent(
            "test-desk-\(UUID().uuidString)"
        )
        let config = base.appendingPathComponent("config")
        try TestDeskFixture.write(
            config: config,
            machine: base.appendingPathComponent("machine")
        )
        return config
    }

    @Test("the checked-in desk is the stores' bytes")
    @MainActor
    func desksMatch() throws {
        let checkedIn = TestDeskFixture.configDirectory
        if Self.regen {
            try? FileManager.default.removeItem(at: checkedIn)
            try TestDeskFixture.write(
                config: checkedIn,
                machine: testTemporaryDirectory.appendingPathComponent(
                    "test-desk-discard-\(UUID().uuidString)"
                )
            )
        }
        let built = try Self.fresh()
        let names = try Self.files(under: built)
        #expect(names.contains("gui.json"), "the build writes a desk")
        #expect(
            try Self.files(under: checkedIn) == names,
            "the desk's files differ; \(Self.hint)"
        )
        for name in names {
            let want = try Data(
                contentsOf: built.appendingPathComponent(name)
            )
            let have = try? Data(
                contentsOf: checkedIn.appendingPathComponent(name)
            )
            #expect(have == want, "\(name) is stale; \(Self.hint)")
        }
    }

    /// Off on a regeneration, which rewrites the files it reads.
    @Test(
        "every versioned file is current and decodes strictly",
        .disabled(if: regen)
    )
    func filesAreCurrent() throws {
        let root = TestDeskFixture.configDirectory
        let gui = try Data(contentsOf: root.appendingPathComponent("gui.json"))
        #expect(!ConfigMigration.needsMigration(gui))
        let config = try JSONDecoder().decode(GuiConfig.self, from: gui)
        #expect(config.format == GuiConfig.currentFormat)
        let profiles = root.appendingPathComponent("profiles")
        let names = try FileManager.default
            .contentsOfDirectory(atPath: profiles.path)
            .filter { $0.hasSuffix(".json") }
        #expect(names.count == TestDeskFixture.profiles().count)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for name in names {
            let data = try Data(
                contentsOf: profiles.appendingPathComponent(name)
            )
            #expect(!ConfigMigration.needsMigration(data), "\(name)")
            let profile = try decoder.decode(Profile.self, from: data)
            #expect(profile.format == Profile.currentFormat, "\(name)")
        }
    }
}
