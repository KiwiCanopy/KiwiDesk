import Foundation
import Testing

@testable import KiwiDeskCore

/// A #1741 capture is its FILE's, filed under its name (#1975): a
/// deleted profile's capture leaves with it and a renamed one's
/// follows it, so a later profile under that name crosses on the
/// settled values rather than another file's.
@Suite("App-wide capture follows its profile (#1975)", .serialized)
@MainActor
struct AppWideCaptureFollowsTests {
    private func makeGuiCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-appwide-follow-\(UUID().uuidString)"
                )
        )
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

    /// Saves `name` with the pre-#1741 keys written into its file.
    private func saveLegacy(_ name: String, in core: KiwiCore) throws {
        try core.profiles.save(profile(named: name))
        let url = try core.profiles.fileURL(name: name)
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        var settings = try #require(root["settings"] as? [String: Any])
        settings["refusal"] = ["sound": true]
        var quit = settings["quit"] as? [String: Any] ?? [:]
        quit["grid_target_depth"] = 9
        settings["quit"] = quit
        root["settings"] = settings
        try JSONSerialization.data(withJSONObject: root).write(to: url)
    }

    private func run(_ command: String, _ name: String, _ core: KiwiCore) {
        #expect(
            core.execute(command, args: [.string(name)]).isSuccess,
            "\(command) \(name)"
        )
    }

    @Test("a deleted profile's capture leaves with it")
    func deleteForgets() throws {
        let core = try makeGuiCore()
        try saveLegacy("Coding", in: core)
        core.prepareAppWide()
        run("delete_profile", "Coding", core)
        try core.profiles.write(profile(named: "Coding"))
        run("load_profile", "Coding", core)
        #expect(core.appWide == AppWideSettings())
        #expect(core.guiConfigStore.load()?.appWide == AppWideSettings())
    }

    @Test("a renamed profile's capture follows it")
    func renameFollows() throws {
        let core = try makeGuiCore()
        try saveLegacy("Work", in: core)
        core.prepareAppWide()
        try core.renameProfile(from: "Work", to: "Home")
        run("load_profile", "Home", core)
        #expect(core.appWide.refusalSound)
        #expect(core.appWide.quitGridTargetDepth == 9)
    }

    @Test("a renamed profile's old name owes nothing")
    func renameLeavesTheOldName() throws {
        let core = try makeGuiCore()
        try saveLegacy("Work", in: core)
        core.prepareAppWide()
        try core.renameProfile(from: "Work", to: "Home")
        try core.profiles.write(profile(named: "Work"))
        run("load_profile", "Work", core)
        #expect(core.appWide == AppWideSettings())
    }
}
