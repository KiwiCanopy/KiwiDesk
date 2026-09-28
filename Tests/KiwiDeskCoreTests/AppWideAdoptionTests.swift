import Foundation
import Testing

@testable import KiwiDeskCore

/// The one-shot crossing out of the profiles (#1741): the first
/// profile applied after the upgrade — the live one — lends its
/// own file's values to `gui.json`, once; after that no profile
/// apply touches them.
@Suite("App-wide settings adoption (#1741)", .serialized)
@MainActor
struct AppWideAdoptionTests {
    private func makeGuiCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-appwide-adopt-\(UUID().uuidString)"
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

    /// Saves `name` and writes the pre-#1741 keys into its file,
    /// the shape an older build left on disk.
    private func saveLegacy(
        _ name: String,
        sound: Bool,
        depth: Int,
        in core: KiwiCore
    ) throws {
        try core.profiles.save(profile(named: name))
        let url = try core.profiles.fileURL(name: name)
        var root = try #require(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: url)
            ) as? [String: Any]
        )
        var settings = try #require(
            root["settings"] as? [String: Any]
        )
        settings["refusal"] = ["sound": sound]
        var quit = settings["quit"] as? [String: Any] ?? [:]
        quit["grid_target_depth"] = depth
        settings["quit"] = quit
        root["settings"] = settings
        try JSONSerialization.data(withJSONObject: root)
            .write(to: url)
    }

    /// What a config load does first: read gui.json and capture
    /// what the crossing owes.
    private func prepare(_ core: KiwiCore) {
        core.prepareAppWide()
    }

    private func load(_ name: String, _ core: KiwiCore) {
        #expect(
            core.execute("load_profile", args: [.string(name)])
                .isSuccess
        )
    }

    @Test("the first applied profile's values are adopted")
    func firstApplyAdopts() throws {
        let core = try makeGuiCore()
        try saveLegacy("Work", sound: true, depth: 9, in: core)
        prepare(core)
        load("Work", core)
        #expect(core.appWide.refusalSound)
        #expect(core.appWide.quitGridTargetDepth == 9)
        let stored = try #require(core.guiConfigStore.load()?.appWide)
        #expect(stored.refusalSound)
        #expect(stored.quitGridTargetDepth == 9)
    }

    /// One-shot: a second profile with different stored values
    /// changes nothing — the values are app-wide now.
    @Test("a later profile apply leaves them alone")
    func adoptionIsOneShot() throws {
        let core = try makeGuiCore()
        try saveLegacy("Work", sound: true, depth: 9, in: core)
        try saveLegacy("Home", sound: false, depth: 2, in: core)
        prepare(core)
        load("Work", core)
        load("Home", core)
        #expect(core.appWide.refusalSound)
        #expect(core.appWide.quitGridTargetDepth == 9)
        #expect(core.guiConfigStore.load()?.appWide?.refusalSound == true)
    }

    /// A gui.json that already carries them outranks every
    /// profile file, whichever applies first.
    @Test("stored values are never overwritten by a profile")
    func storedOutranksProfiles() throws {
        let core = try makeGuiCore()
        core.setAppWide(persisting: true) { $0.quitGridTargetDepth = 4 }
        try saveLegacy("Work", sound: true, depth: 9, in: core)
        prepare(core)
        load("Work", core)
        #expect(!core.appWide.refusalSound)
        #expect(core.appWide.quitGridTargetDepth == 4)
    }

    /// A profile file carrying neither key keeps the settled
    /// values — not the defaults, not a verb's session value — and
    /// still ends the crossing.
    @Test("a profile without the keys keeps the settled values")
    func keylessProfileEndsTheCrossing() throws {
        let core = try makeGuiCore()
        try core.profiles.save(profile(named: "Fresh"))
        // Settled at 4, then a gui.json without the keys owes a
        // crossing again.
        core.setAppWide(persisting: true) {
            $0.quitGridTargetDepth = 4
        }
        try Data(#"{"format":4}"#.utf8).write(to: core.guiConfigStore.url)
        core.setAppWide(persisting: false) {
            $0.quitGridTargetDepth = 7
        }
        prepare(core)
        load("Fresh", core)
        let stored = core.guiConfigStore.load()?.appWide
        #expect(stored?.quitGridTargetDepth == 4)
    }

    /// A Lua-owned config has no gui.json store: init.lua is the
    /// store, so nothing is adopted or written.
    @Test("a Lua-owned config adopts nothing")
    func luaOwnedAdoptsNothing() throws {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-appwide-lua-\(UUID().uuidString)"
                )
        )
        try saveLegacy("Work", sound: true, depth: 9, in: core)
        prepare(core)
        load("Work", core)
        #expect(!core.appWide.refusalSound)
        #expect(!core.guiConfigStore.exists)
    }

    /// Lua-owned beside an existing gui.json (init.lua touches the
    /// managed vocabulary): still nothing is adopted or stripped.
    @Test("a Lua-owned config beside a gui.json adopts nothing")
    func luaOwnedBesideSidecarAdoptsNothing() throws {
        for reloads in [true, false] {
            let core = try makeGuiCore()
            try saveLegacy("Work", sound: true, depth: 9, in: core)
            // Owed while GUI-managed, then init.lua takes over.
            prepare(core)
            try "KiwiDesk.bind(\"cmd+h\", function() end)\n".write(
                to: core.configURL,
                atomically: true,
                encoding: .utf8
            )
            #expect(!core.isGuiManaged)
            // With a reload the load clears the debt; without one
            // the apply refuses it.
            if reloads {
                prepare(core)
                #expect(core.appWideLedger.owed == nil)
            }
            load("Work", core)
            #expect(!core.appWide.refusalSound, "reloads: \(reloads)")
            #expect(
                core.guiConfigStore.load()?.appWide == nil,
                "reloads: \(reloads)"
            )
        }
    }

    /// A row has no store to write under a Lua-owned config: the
    /// session changes, gui.json does not.
    @Test("a row write refuses under a Lua-owned config")
    func rowRefusesUnderLua() throws {
        let core = try makeGuiCore()
        try "KiwiDesk.bind(\"cmd+h\", function() end)\n".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        #expect(!core.isGuiManaged)
        core.setAppWide(persisting: true) {
            $0.quitGridTargetDepth = 6
        }
        #expect(core.appWide.quitGridTargetDepth == 6)
        #expect(core.guiConfigStore.load()?.appWide == nil)
    }
}
