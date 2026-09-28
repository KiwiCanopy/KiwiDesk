import Foundation
import Testing

@testable import KiwiDeskCore

/// The #1741 crossing across a backup restore: a bundle that
/// stores the values brings them, and one written before #1741
/// brings its inline profiles' values — to that bundle's restore
/// alone — without this Mac's being stamped into the file.
@Suite("App-wide settings across a restore (#1741)", .serialized)
@MainActor
struct AppWideBackupTests {
    private func directory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-appwide-end-\(UUID().uuidString)")
    }

    private func makeGuiCore() throws -> KiwiCore {
        let core = makeTestCore(configDirectory: directory())
        try core.guiConfigStore.save(GuiConfig())
        return core
    }

    private func profile(named name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    private func load(_ name: String, _ core: KiwiCore) {
        #expect(
            core.execute("load_profile", args: [.string(name)])
                .isSuccess
        )
    }

    /// A backup written before #1741: one profile, "Work", whose
    /// inline settings carry the retired groups.
    private func legacyBackup(in core: KiwiCore) throws -> URL {
        let bundle = SetupBundle(
            writtenBy: "test",
            config: GuiConfig(),
            profiles: [profile(named: "Work")],
            palettes: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var root = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(bundle))
                as? [String: Any]
        )
        var profiles = try #require(root["profiles"] as? [[String: Any]])
        var settings = try #require(
            profiles[0]["settings"] as? [String: Any]
        )
        settings["refusal"] = ["sound": true]
        settings["quit"] = ["grid_target_depth": 9, "layout": "grid"]
        profiles[0]["settings"] = settings
        root["profiles"] = profiles
        let url = directory().appendingPathExtension("json")
        try JSONSerialization.data(withJSONObject: root).write(to: url)
        return url
    }

    /// A backup from before #1741 keeps the values in its inline
    /// profiles, which their decode drops; the restore adopts the
    /// applied profile's from the bytes `readBackup` read.
    @Test("a pre-#1741 backup's profile values are adopted")
    func oldBackupValuesCross() throws {
        let core = try makeGuiCore()
        let url = try legacyBackup(in: core)
        let read = try core.readBackup(at: url)
        try core.restoreSetup(from: read) { _ in }
        load("Work", core)
        #expect(core.appWide.refusalSound)
        #expect(core.appWide.quitGridTargetDepth == 9)
        #expect(core.guiConfigStore.load()?.appWide?.refusalSound == true)
    }

    /// Values read from one backup are never owed to another.
    @Test("another bundle's restore owes nothing read earlier")
    func otherBundleOwesNothing() throws {
        let core = try makeGuiCore()
        let read = try core.readBackup(at: legacyBackup(in: core))
        #expect(read.profiles.count == 1)
        let other = SetupBundle(
            writtenBy: "other",
            config: GuiConfig(),
            profiles: [profile(named: "Work")],
            palettes: []
        )
        try core.restoreSetup(from: other) { _ in }
        load("Work", core)
        #expect(!core.appWide.refusalSound)
        #expect(
            core.appWide.quitGridTargetDepth
                == QuitGridLayout.defaultTargetDepth
        )
    }

    /// A restore takes the bundle's values over the ones this Mac
    /// already stored, which every write would otherwise stamp in.
    @Test("a restore takes the bundle's values")
    func restoreTakesTheBundle() throws {
        let core = try makeGuiCore()
        core.setAppWide(persisting: true) { $0.quitGridTargetDepth = 4 }
        var config = GuiConfig()
        var wide = AppWideSettings()
        wide.refusalSound = true
        wide.quitGridTargetDepth = 12
        config.appWide = wide
        let bundle = SetupBundle(
            writtenBy: "test",
            config: config,
            profiles: [],
            palettes: []
        )
        try core.restoreSetup(from: bundle) { _ in }
        #expect(core.appWide == wide)
        #expect(core.guiConfigStore.load()?.appWide == wide)
    }

    /// A bundle that stores no values: nothing of this Mac's is
    /// stamped into the restored file.
    @Test("a restore without values stamps none of this Mac's")
    func restoreWithoutValues() throws {
        let core = try makeGuiCore()
        core.setAppWide(persisting: true) {
            $0.quitGridTargetDepth = 4
        }
        let bundle = SetupBundle(
            writtenBy: "test",
            config: GuiConfig(),
            profiles: [],
            palettes: []
        )
        try core.restoreSetup(from: bundle) { _ in }
        let written = try #require(core.guiConfigStore.load())
        #expect(written.appWide == nil)
        #expect(core.appWide.quitGridTargetDepth == 4)
    }

    /// And when its profiles carry none either, the first apply
    /// keeps this Mac's values rather than the defaults.
    @Test("the first apply after such a restore keeps this Mac's")
    func restoreWithoutValuesThenApply() throws {
        let core = try makeGuiCore()
        core.setAppWide(persisting: true) {
            $0.quitGridTargetDepth = 4
        }
        let bundle = SetupBundle(
            writtenBy: "test",
            config: GuiConfig(),
            profiles: [profile(named: "Work")],
            palettes: []
        )
        try core.restoreSetup(from: bundle) { _ in }
        load("Work", core)
        #expect(core.appWide.quitGridTargetDepth == 4)
        #expect(
            core.guiConfigStore.load()?.appWide?.quitGridTargetDepth
                == 4
        )
    }
}
