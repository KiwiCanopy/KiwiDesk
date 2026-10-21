import Foundation
import Testing

@testable import KiwiDeskCore

/// A store whose file a newer KiwiDesk wrote is read-only on this
/// build and says so (#2324 ruling 2): one predicate, a Config
/// Issue per store, a profile cause that offers no Delete, and the
/// latch Settings greys its Save on. Fixtures are this build's own
/// files re-stamped one format up, so they differ by the format
/// alone.
@Suite("Newer-format latch (#2324)", .serialized)
@MainActor
struct NewerFormatLatchTests {
    private func scratch() throws -> URL {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent("kiwi-latch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    /// Writes `value` to `file` with its `format` set to `format`.
    private func write<T: Encodable>(
        _ value: T,
        to file: URL,
        format: Int
    ) throws {
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(value).write(to: file)
        try restamp(file, to: format)
    }

    /// Re-stamps `file`'s top-level `format`.
    private func restamp(_ file: URL, to format: Int) throws {
        var root = try #require(
            try JSONSerialization.jsonObject(
                with: Data(contentsOf: file)
            ) as? [String: Any]
        )
        root["format"] = format
        try JSONSerialization.data(withJSONObject: root)
            .write(to: file)
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A"])],
            spaceModes: ["1": .bsp],
            settings: TilingSettings(),
            savedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )
    }

    @Test("The predicate counts only a readable format above")
    func predicate() {
        func newer(_ json: String) -> Int? {
            NewerFormatOnDisk.newerFormat(of: Data(json.utf8), knows: 3)
        }
        #expect(newer(#"{"format": 4}"#) == 4)
        #expect(newer(#"{"format": 3}"#) == nil)
        #expect(newer(#"{"format": 1}"#) == nil)
        #expect(newer(#"{"format": "4"}"#) == nil)
        #expect(newer(#"{}"#) == nil)
        #expect(newer("not json") == nil)
    }

    @Test("Each store's newer file raises its own issue")
    func everyStoreRaisesAnIssue() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        #expect(core.newerFormatIssues().isEmpty)
        try write(
            GuiConfig(),
            to: core.url(of: .guiConfig),
            format: GuiConfig.currentFormat + 1
        )
        try write(
            PaletteDocument(palettes: []),
            to: core.url(of: .palettes),
            format: PaletteDocument.currentFormat + 1
        )
        try write(
            LookDocument(looks: []),
            to: core.url(of: .looks),
            format: LookDocument.currentFormat + 1
        )
        try write(
            MachineConfig(),
            to: core.url(of: .machineConfig),
            format: MachineConfig.currentFormat + 1
        )
        try write(
            DesktopBindingsFile(),
            to: core.url(of: .desktopBindings),
            format: DesktopBindingsFile.currentFormat + 1
        )
        let artifacts: [ConfigArtifact] = [
            .guiConfig, .palettes, .looks, .machineConfig,
            .desktopBindings,
        ]
        #expect(
            core.newerFormatIssues()
                == artifacts.map {
                    ConfigIssue(
                        source: core.url(of: $0).lastPathComponent,
                        kind: .newerFormat($0)
                    )
                }
        )
        core.refreshConfigIssues()
        #expect(
            core.configIssues.filter {
                if case .newerFormat = $0.kind { return true }
                return false
            }.count == artifacts.count
        )
    }

    @Test("A newer gui.json reads as newer, never as unreadable")
    func newerSidecarIsNotUnreadable() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        try write(
            GuiConfig(),
            to: core.url(of: .guiConfig),
            format: GuiConfig.currentFormat + 1
        )
        core.loadConfig()
        let kinds = core.configIssues.map(\.kind)
        #expect(kinds.contains(.newerFormat(.guiConfig)))
        #expect(!kinds.contains(.guiConfigUnreadable))
        // The control: a corrupt sidecar is still unreadable.
        try Data("{".utf8).write(to: core.url(of: .guiConfig))
        core.loadConfig()
        #expect(core.configIssues.map(\.kind).contains(.guiConfigUnreadable))
    }

    @Test("A newer profile is broken as newer, and is never deleted")
    func newerProfileIsKept() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        try core.profiles.write(profile("Desk"))
        try core.profiles.write(profile("Laptop"))
        let file = try core.profiles.fileURL(name: "Desk")
        try restamp(file, to: Profile.currentFormat + 1)
        let causes = Dictionary(
            uniqueKeysWithValues: core.profiles.brokenProfiles().map {
                ($0.name, $0.cause)
            }
        )
        #expect(causes == ["Desk": .newerFormat])
        #expect(
            core.profileConfigIssues().map(\.kind)
                == [.profileBroken(.newerFormat)]
        )
        let before = try Data(contentsOf: file)
        #expect(throws: NewerFormatOnDisk.self) {
            try core.profiles.delete(name: "Desk")
        }
        #expect(try Data(contentsOf: file) == before)
        // The control: a current profile still deletes.
        try core.profiles.delete(name: "Laptop")
        #expect(!core.profiles.list().contains("Laptop"))
    }

    @Test("Settings' Save latches on each file its write refuses")
    func saveLatch() throws {
        // A newer library is no Settings Save's to refuse.
        let libraries = makeTestCore()
        try libraries.guiConfigStore.save(GuiConfig())
        #expect(libraries.guiConfigWriteLatch() == nil)
        try write(
            PaletteDocument(palettes: []),
            to: libraries.url(of: .palettes),
            format: PaletteDocument.currentFormat + 1
        )
        #expect(libraries.guiConfigWriteLatch() == nil)
        // One file newer at a time, on a core of its own, so each
        // file's own check is what refuses.
        let cases: [(ConfigArtifact, Int)] = [
            (.desktopBindings, DesktopBindingsFile.currentFormat),
            (.machineConfig, MachineConfig.currentFormat),
            (.guiConfig, GuiConfig.currentFormat),
        ]
        for (artifact, format) in cases {
            let core = makeTestCore()
            try core.guiConfigStore.saveIncludingBindings(GuiConfig())
            try restamp(core.url(of: artifact), to: format + 1)
            #expect(core.guiConfigWriteLatch()?.artifact == artifact)
            // A greyed Save always has its Config Issue beside it.
            #expect(
                core.newerFormatIssues().map(\.kind)
                    == [.newerFormat(artifact)]
            )
            #expect(throws: NewerFormatOnDisk.self) {
                try core.guiConfigStore.saveIncludingBindings(GuiConfig())
            }
        }
    }

    @Test("A refusal names its file by structure")
    func refusalNamesItsFile() throws {
        let core = makeTestCore()
        for artifact in ConfigArtifact.allCases {
            guard let name = artifact.fileName else { continue }
            #expect(name == core.url(of: artifact).lastPathComponent)
        }
        #expect(
            NewerFormatOnDisk(artifact: .profiles, profile: "Desk", format: 9)
                .fileName == "Desk.json"
        )
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("Desk.json")
        try write(profile("Desk"), to: file, format: Profile.currentFormat + 1)
        #expect(
            NewerFormatOnDisk.checkProfile(file)
                == NewerFormatOnDisk(
                    artifact: .profiles,
                    profile: "Desk",
                    format: Profile.currentFormat + 1
                )
        )
    }
}
