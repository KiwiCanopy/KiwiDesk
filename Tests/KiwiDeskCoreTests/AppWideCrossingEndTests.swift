import Foundation
import Testing

@testable import KiwiDeskCore

/// How the #1741 crossing ENDS, and what never feeds it: the
/// values are captured before any profile rewrite, the retired
/// keys leave every profile file, an unreadable `gui.json` owes
/// nothing, a verb never reaches the file, and a restore and a
/// Lua-to-GUI adoption carry their own values.
@Suite("App-wide settings crossing end (#1741)", .serialized)
@MainActor
struct AppWideCrossingEndTests {
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

    /// Saves `name` with the pre-#1741 keys written into its file.
    private func saveLegacy(
        _ name: String,
        depth: Int,
        sound: Bool = true,
        in core: KiwiCore
    ) throws {
        try core.profiles.save(profile(named: name))
        let url = try core.profiles.fileURL(name: name)
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        var settings = try #require(root["settings"] as? [String: Any])
        settings["refusal"] = ["sound": sound]
        var quit = settings["quit"] as? [String: Any] ?? [:]
        quit["grid_target_depth"] = depth
        settings["quit"] = quit
        root["settings"] = settings
        try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: url)
    }

    private func load(_ name: String, _ core: KiwiCore) {
        #expect(
            core.execute("load_profile", args: [.string(name)])
                .isSuccess
        )
    }

    private func text(_ name: String, _ core: KiwiCore) throws -> String {
        try String(
            contentsOf: core.profiles.fileURL(name: name),
            encoding: .utf8
        )
    }

    /// The #1530 settle re-encodes profiles through a coder that
    /// no longer writes the keys; the capture must precede it.
    @Test("the capture survives a profile rewrite before the apply")
    func captureBeforeRewrite() throws {
        let core = try makeGuiCore()
        try saveLegacy("Work", depth: 9, in: core)
        core.prepareAppWide()
        try core.profiles.write(profile(named: "Work"))
        load("Work", core)
        #expect(core.appWide.refusalSound)
        #expect(core.appWide.quitGridTargetDepth == 9)
    }

    @Test("adoption strips the retired keys from every profile")
    func adoptionStripsEveryProfile() throws {
        let core = try makeGuiCore()
        try saveLegacy("Work", depth: 9, in: core)
        try saveLegacy("Home", depth: 2, in: core)
        core.prepareAppWide()
        load("Work", core)
        for name in ["Work", "Home"] {
            let body = try text(name, core)
            #expect(!body.contains("grid_target_depth"), "\(name)")
            #expect(!body.contains("\"refusal\""), "\(name)")
            #expect(!body.contains("\"quit\""), "\(name)")
            #expect(body.contains("\"settings\""), "\(name) kept")
        }
    }

    /// Keys out of sorted order, so the re-serializing fallback
    /// (sorted keys) cannot produce the expected text by accident.
    @Test("the strip keeps the rest of the file byte for byte")
    func stripIsSurgical() throws {
        let data = Data(
            """
            {
              "settings" : {
                "zeta" : 1,
                "quit" : {
                  "grid_target_depth" : 7,
                  "layout" : "grid"
                },
                "gap" : 0.4,
                "refusal" : {
                  "sound" : true
                }
              }
            }
            """.utf8
        )
        let out = try #require(
            ConfigMigration.withoutLegacyAppWide(data)
        )
        let expected = """
            {
              "settings" : {
                "zeta" : 1,
                "gap" : 0.4
              }
            }
            """
        #expect(String(data: out, encoding: .utf8) == expected)
    }

    /// Nothing stored yet (the crossing still owed): a row write
    /// builds on the settled values, never on a verb's.
    @Test("a row before any store never carries a verb's value")
    func rowBeforeStoreSkipsTheVerb() throws {
        let core = try makeGuiCore()
        core.prepareAppWide()
        #expect(
            core.execute("set_refusal_sound", args: [.bool(true)])
                .isSuccess
        )
        core.setAppWide(persisting: true) {
            $0.quitGridTargetDepth = 6
        }
        let stored = try #require(core.guiConfigStore.load()?.appWide)
        #expect(stored.quitGridTargetDepth == 6)
        #expect(!stored.refusalSound)
        // Ending the crossing, the engine runs what was stored.
        #expect(core.appWide == stored)
    }

    /// A row written while the crossing is owed ends it through the
    /// apply's own door: stored, and the profile files stripped.
    @Test("a row while owed ends the crossing")
    func rowWhileOwedEndsTheCrossing() throws {
        let core = try makeGuiCore()
        try saveLegacy("Work", depth: 9, in: core)
        core.prepareAppWide()
        core.setAppWide(persisting: true) {
            $0.quitGridTargetDepth = 6
        }
        let stored = try #require(core.guiConfigStore.load()?.appWide)
        #expect(stored.quitGridTargetDepth == 6)
        // "Work" is live (a save adopts it), so its captured sound
        // is what the row's crossing adopts beside the row's depth.
        #expect(core.profiles.currentName == "Work")
        #expect(stored.refusalSound)
        #expect(!(try text("Work", core)).contains("grid_target_depth"))
        #expect(core.appWideLedger.owed == nil)
    }

    /// A failed gui.json write keeps every profile's copy, so the
    /// next launch can still cross.
    @Test("a failed adoption write strips nothing")
    func failedWriteKeepsTheProfiles() throws {
        let core = try makeGuiCore()
        try saveLegacy("Work", depth: 9, in: core)
        core.prepareAppWide()
        try Data("{ not json".utf8).write(to: core.guiConfigStore.url)
        load("Work", core)
        #expect(try text("Work", core).contains("grid_target_depth"))
        // Nothing was stored either, so a later unrelated write
        // cannot end the crossing without the strip.
        try core.guiConfigStore.save(GuiConfig())
        #expect(core.guiConfigStore.load()?.appWide == nil)
    }

    /// Absence the load could not confirm is not a crossing owed.
    @Test("an unreadable gui.json owes nothing")
    func unreadableOwesNothing() throws {
        let core = try makeGuiCore()
        try saveLegacy("Work", depth: 9, in: core)
        try Data("{ not json".utf8).write(to: core.guiConfigStore.url)
        core.prepareAppWide()
        load("Work", core)
        #expect(!core.appWide.refusalSound)
        #expect(try text("Work", core).contains("grid_target_depth"))
    }

    /// A verb is the session's: an unrelated write never saves it.
    @Test("a verb never reaches gui.json")
    func verbNeverPersists() throws {
        let core = try makeGuiCore()
        core.setAppWide(persisting: true) { $0.quitGridTargetDepth = 4 }
        #expect(
            core.execute(
                "quit.set_grid_target_depth",
                args: [.number(12)]
            ).isSuccess
        )
        #expect(core.appWide.quitGridTargetDepth == 12)
        let config = try #require(core.guiConfigStore.load())
        try core.guiConfigStore.save(config)
        #expect(
            core.guiConfigStore.load()?.appWide?.quitGridTargetDepth
                == 4
        )
    }

    /// Lua-to-GUI adoption carries what init.lua executed.
    @Test("adopting a Lua config carries its values")
    func luaAdoptionCarries() throws {
        let core = makeTestCore(configDirectory: directory())
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try """
        KiwiDesk.set_refusal_sound(true)
        KiwiDesk.bind("cmd+h", function() KiwiDesk.focus("left") end)
        """.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        #expect(core.appWide.refusalSound)
        // A profile copy that disagrees with init.lua: only the
        // executed value may reach gui.json.
        try saveLegacy("Work", depth: 9, sound: false, in: core)
        try core.adoptConfigIntoGui { _ in }
        #expect(core.guiConfigStore.load()?.appWide?.refusalSound == true)
        #expect(core.appWide.refusalSound)
        // The crossing ends in the files on this door too.
        #expect(!(try text("Work", core)).contains("grid_target_depth"))
    }
}
