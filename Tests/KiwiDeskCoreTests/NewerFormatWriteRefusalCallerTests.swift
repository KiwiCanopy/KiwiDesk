import Foundation
import Testing

@testable import KiwiDeskCore

/// The writers beside the two doors that a newer file must also
/// stop (#2325): a raw profile rewrite, and the sequences that
/// write something else before the door refuses. Each case has a
/// control proving the fixture reaches the write it guards.
@Suite("Newer-format write refusal — callers", .serialized)
@MainActor
struct NewerFormatWriteRefusalCallerTests {
    private func scratch() throws -> URL {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwi-newer-callers-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir
    }

    private func profile(
        _ name: String,
        dormant: Bool = false,
        isDefault: Bool = false
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: dormant ? [] : [MonitorSet(monitors: ["A"])],
            monitorCount: dormant ? 1 : nil,
            isDefault: isDefault,
            spaceModes: ["1": .bsp],
            settings: TilingSettings(),
            savedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )
    }

    /// `file`'s root with `edit` applied, written back.
    private func rewrite(
        _ file: URL,
        _ edit: (inout [String: Any]) -> Void
    ) throws {
        let data = try Data(contentsOf: file)
        var root = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        edit(&root)
        try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: file)
    }

    private func withRetiredGroup(_ newer: Bool) -> (
        inout [String: Any]
    ) -> Void {
        { root in
            var settings = root["settings"] as? [String: Any] ?? [:]
            settings[ConfigMigration.retiredRefusalGroup] = [
                "sound": true
            ]
            root["settings"] = settings
            if newer { root["format"] = Profile.currentFormat + 1 }
        }
    }

    @Test("The app-wide strip leaves a newer profile file alone")
    func stripSkipsNewer() throws {
        for newer in [false, true] {
            let dir = try scratch()
            defer { try? FileManager.default.removeItem(at: dir) }
            let core = makeTestCore(configDirectory: dir)
            try core.profiles.write(profile("Desk"))
            let file = try core.profiles.fileURL(name: "Desk")
            try rewrite(file, withRetiredGroup(newer))
            let before = try Data(contentsOf: file)
            core.stripLegacyAppWide()
            let after = try Data(contentsOf: file)
            // The control: a current file IS stripped.
            #expect((after == before) == newer)
        }
    }

    @Test("A refused save rewrites no sibling first")
    func saveRefusesBeforeSiblings() throws {
        for newer in [false, true] {
            let dir = try scratch()
            defer { try? FileManager.default.removeItem(at: dir) }
            let core = makeTestCore(configDirectory: dir)
            try core.profiles.write(
                profile("Old", dormant: true, isDefault: true)
            )
            try core.profiles.write(profile("Desk"))
            let desk = try core.profiles.fileURL(name: "Desk")
            if newer {
                try rewrite(desk) {
                    $0["format"] = Profile.currentFormat + 1
                }
            }
            let old = try core.profiles.fileURL(name: "Old")
            let before = try Data(contentsOf: old)
            _ = try? core.profiles.save(profile("Desk"))
            let after = try Data(contentsOf: old)
            // The control: a current target clears the sibling.
            #expect((after == before) == newer)
        }
    }

    @Test("An adoption over a newer gui.json records no store")
    func adoptRefusesBeforeTheLedger() throws {
        let dir = try scratch()
        defer { try? FileManager.default.removeItem(at: dir) }
        let core = makeTestCore(configDirectory: dir)
        try core.guiConfigStore.save(GuiConfig())
        try rewrite(core.guiConfigStore.url) {
            $0["format"] = GuiConfig.currentFormat + 1
        }
        let before = try Data(contentsOf: core.guiConfigStore.url)
        #expect(!core.appWideLedger.isStored)
        #expect(throws: NewerFormatOnDisk.self) {
            try core.adoptConfigIntoGui(classifying: { _ in })
        }
        #expect(!core.appWideLedger.isStored)
        #expect(
            try Data(contentsOf: core.guiConfigStore.url) == before
        )
    }
}
