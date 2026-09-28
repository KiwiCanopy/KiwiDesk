import Foundation
import Testing

@testable import KiwiDeskCore

/// Where the app-wide settings live (#1741): `gui.json` carries
/// them under their Lua-derived keys, a file from before carries
/// none and reads as "not adopted", and every write stamps the
/// live values rather than the caller's copy.
@Suite("App-wide settings in gui.json (#1741)", .serialized)
@MainActor
struct AppWideSettingsTests {
    private func object(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
    }

    @Test("gui.json writes refusal.sound and quit.grid_target_depth")
    func encodesTheLuaKeys() throws {
        var config = GuiConfig()
        var wide = AppWideSettings()
        wide.refusalSound = true
        wide.quitGridTargetDepth = 9
        config.appWide = wide
        let root = try object(JSONEncoder().encode(config))
        let refusal = try #require(root["refusal"] as? [String: Any])
        let quit = try #require(root["quit"] as? [String: Any])
        #expect(refusal["sound"] as? Bool == true)
        #expect(quit["grid_target_depth"] as? Int == 9)
        let back = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONEncoder().encode(config)
        )
        #expect(back.appWide == wide)
    }

    /// Absence is the crossing's signal, so it must survive a
    /// round trip as absence rather than as the defaults.
    @Test("a file without them stays unadopted")
    func absenceIsNotTheDefaults() throws {
        let root = try object(JSONEncoder().encode(GuiConfig()))
        #expect(root["refusal"] == nil)
        #expect(root["quit"] == nil)
        let decoded = try JSONDecoder().decode(
            GuiConfig.self,
            from: Data(#"{"format":4}"#.utf8)
        )
        #expect(decoded.appWide == nil)
    }

    @Test("a profile's settings no longer carry them")
    func profileSettingsDropThem() throws {
        let root = try object(JSONEncoder().encode(TilingSettings()))
        #expect(root["refusal"] == nil)
        #expect(root["quit"] == nil)
    }

    @Test("the legacy reader finds a profile file's values")
    func legacyReader() throws {
        let json =
            #"{"settings":{"refusal":{"sound":true},"#
            + #""quit":{"layout":"grid","grid_target_depth":3}}}"#
        let both = Data(json.utf8)
        let read = try #require(
            ConfigMigration.legacyAppWide(inProfile: both)
        )
        #expect(read.refusalSound)
        #expect(read.quitGridTargetDepth == 3)
        #expect(read.quitLayout == .grid)
        // `layout` alone is a retired value too.
        let layoutOnly = Data(
            #"{"settings":{"quit":{"layout":"grid"}}}"#.utf8
        )
        #expect(ConfigMigration.legacyAppWide(inProfile: layoutOnly) != nil)
        let depthOnly = Data(
            #"{"settings":{"quit":{"grid_target_depth":99}}}"#.utf8
        )
        let clamped = try #require(
            ConfigMigration.legacyAppWide(inProfile: depthOnly)
        )
        #expect(!clamped.refusalSound)
        #expect(
            clamped.quitGridTargetDepth
                == QuitGridLayout.targetDepthRange.upperBound
        )
        let low = Data(
            #"{"settings":{"quit":{"grid_target_depth":-3}}}"#.utf8
        )
        #expect(
            ConfigMigration.legacyAppWide(inProfile: low)?
                .quitGridTargetDepth
                == QuitGridLayout.targetDepthRange.lowerBound
        )
        let neither = Data(
            #"{"settings":{"gap":{"inner":4}}}"#.utf8
        )
        #expect(ConfigMigration.legacyAppWide(inProfile: neither) == nil)
    }

    /// A Settings save hands back a config it loaded earlier; the
    /// store stamps the live values over that copy, as it does the
    /// Desktop memory (#1230).
    @Test("a write stamps the live values over a stale copy")
    func writeStampsLive() throws {
        let core = makeTestCore(configDirectory: tempDirectory())
        try core.guiConfigStore.save(GuiConfig())
        core.setAppWide(persisting: true) { $0.quitGridTargetDepth = 11 }
        var stale = try #require(core.guiConfigStore.load())
        stale.appWide?.quitGridTargetDepth = 2
        try core.guiConfigStore.save(stale)
        let saved = try #require(core.guiConfigStore.load())
        #expect(saved.appWide?.quitGridTargetDepth == 11)
    }

    /// General's rows apply immediately: the value is in the file
    /// before any Save, and a verb stays in the session.
    @Test("a row persists at once; a verb does not")
    func rowPersistsVerbDoesNot() throws {
        let core = makeTestCore(configDirectory: tempDirectory())
        try core.guiConfigStore.save(GuiConfig())
        #expect(
            core.execute(
                "set_refusal_sound",
                args: [.bool(true)]
            ).isSuccess
        )
        #expect(core.appWide.refusalSound)
        #expect(core.guiConfigStore.load()?.appWide == nil)
        core.setAppWide(persisting: true) { $0.quitGridTargetDepth = 6 }
        let saved = try #require(core.guiConfigStore.load()?.appWide)
        #expect(!saved.refusalSound, "a verb rode the row's write")
        #expect(saved.quitGridTargetDepth == 6)
    }

    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-appwide-\(UUID().uuidString)")
    }
}
