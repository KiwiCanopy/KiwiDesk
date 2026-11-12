import Foundation
import Testing

@testable import KiwiDeskCore

/// A lens's fade length and curve overrides are cleared (#3246):
/// Settings no longer draws them, so each lens follows the global
/// fade again. Reached in `gui.json` and a backup's `config`
/// from the format the last release (4.2.1) stamped; the global fade and
/// every other override stay. Fixtures are the encoder's own output.
@Suite("Lens fade migration (#3246)")
struct LensFadeMigrationTests {
    /// Settings with one lens overriding everything, the global
    /// fade off its default so a strip of it would show.
    private var pace: AppWideSettings {
        var pace = AppWideSettings()
        pace.visionFadeDuration = 450
        pace.visionFadeCurve = .linear
        var lens = VisionLens(name: "Writing")
        lens.apps = ["com.apple.textedit"]
        lens.overrides.dim = 40
        lens.overrides.fadeDuration = 700
        lens.overrides.fadeCurve = .easeIn
        var plain = VisionLens(name: "Plain")
        plain.apps = ["com.apple.notes"]
        plain.overrides.fadeCurve = .easeInOut
        pace.visionLenses = [lens, plain]
        return pace
    }

    private var config: GuiConfig {
        var config = GuiConfig()
        config.appWide = pace
        return config
    }

    private func stamped<T: Encodable>(
        _ value: T,
        format: Int
    ) throws -> Data {
        var root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(value)
            ) as? [String: Any]
        )
        root["format"] = format
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
        #expect(String(decoding: data, as: UTF8.self).contains("700"))
        return data
    }

    private func check(_ config: GuiConfig?) throws {
        let pace = try #require(config?.appWide)
        #expect(pace.visionFadeDuration == 450)
        #expect(pace.visionFadeCurve == .linear)
        #expect(pace.visionLenses.count == 2)
        for lens in pace.visionLenses {
            #expect(lens.overrides.fadeDuration == nil)
            #expect(lens.overrides.fadeCurve == nil)
        }
        #expect(pace.visionLenses.first?.overrides.dim == 40)
    }

    /// From 4.2.1's stamp (19), so every later step runs ahead of
    /// this one, and from the format below this step's (23).
    @Test("gui.json crosses", arguments: [19, 23])
    func guiCrosses(from format: Int) throws {
        let data = try stamped(config, format: format)
        let out = try #require(ConfigMigration.migrated(data))
        try check(JSONDecoder().decode(GuiConfig.self, from: out))
    }

    /// From 4.2.1's backup stamp (43) and from 47.
    @Test("a backup's config crosses", arguments: [43, 47])
    func bundleCrosses(from format: Int) throws {
        let bundle = SetupBundle(
            format: format,
            writtenBy: "test",
            config: config,
            profiles: [],
            palettes: []
        )
        let out = try #require(
            ConfigMigration.migrated(stamped(bundle, format: format))
        )
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let inner = try JSONSerialization.data(
            withJSONObject: #require(root["config"])
        )
        try check(JSONDecoder().decode(GuiConfig.self, from: inner))
    }

    /// The edit cuts the two members out of the lens and leaves
    /// every other byte, the global group's keys included.
    @Test("the edit is surgical")
    func editIsSurgical() throws {
        let data = try stamped(config, format: 23)
        let text = String(decoding: data, as: UTF8.self)
        let edited = try #require(ConfigMigration.lensFadeTextDropped(text))
        let out = String(decoding: edited, as: UTF8.self)
        #expect(!out.contains("700"))
        #expect(!out.contains("ease_in\""))
        #expect(out.contains("450"))
        #expect(out.contains("\"linear\""))
        #expect(out.count < text.count)
        _ = try JSONSerialization.jsonObject(with: edited)
        // The step keeps the edit rather than re-serializing.
        #expect(ConfigMigration.migratingLensFadeOut(data) == edited)
    }

    /// At the formats it introduced the step stands down, so a
    /// lens override Lua's later write stores is kept.
    @Test("the step stands down at its own formats")
    func standsDown() throws {
        let gui = try stamped(
            config,
            format: ConfigMigration.lensFadeGuiFormat
        )
        #expect(ConfigMigration.migratingLensFadeOut(gui) == nil)
        let bundle = SetupBundle(
            format: ConfigMigration.lensFadeBundleFormat,
            writtenBy: "test",
            config: config,
            profiles: [],
            palettes: []
        )
        let data = try stamped(
            bundle,
            format: ConfigMigration.lensFadeBundleFormat
        )
        #expect(ConfigMigration.migratingLensFadeOut(data) == nil)
    }

    /// A file with no lens override is left alone.
    @Test("a lens with no fade override changes nothing")
    func nothingToClear() throws {
        var plain = AppWideSettings()
        plain.visionLenses = [VisionLens(name: "Plain")]
        var config = GuiConfig()
        config.appWide = plain
        var root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(config)
            ) as? [String: Any]
        )
        root["format"] = 23
        let data = try JSONSerialization.data(withJSONObject: root)
        #expect(ConfigMigration.migratingLensFadeOut(data) == nil)
    }
}
