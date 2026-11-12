import Foundation
import Testing

@testable import KiwiDeskCore

/// A stored `reveal_duration` or `expand_duration` of 0 crosses to
/// its toggle off plus the default length (#3236), in every shape
/// that carries one: a profile's settings, `gui.json`'s shared
/// look, `looks.json` and a backup's inline copies. Fixtures are
/// the encoder's own output with the old 0 put back, never
/// hand-typed JSON.
@Suite("Instant duration migration")
struct InstantDurationMigrationTests {
    /// Settings whose reveal and expand were tuned (any value the
    /// encoder can write), so their text can carry the old 0.
    private var tuned: TilingSettings {
        var settings = TilingSettings()
        settings.animations.revealDurationMS = 450
        settings.animations.expandDurationMS = 1250
        return settings
    }

    /// `value` encoded, then put back in the older build's shape:
    /// no reveal switch (it is new), each tuned length spelled as
    /// its 0, the look paths included, and `format` stamped.
    private func legacy<T: Encodable>(
        _ value: T,
        format: Int
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var text = try #require(
            String(data: encoder.encode(value), encoding: .utf8)
        )
        #expect(text.contains(": 450"))
        #expect(text.contains(": 1250"))
        text = text.replacingOccurrences(of: ": 450", with: ": 0")
            .replacingOccurrences(of: ": 1250", with: ": 0")
            .replacingOccurrences(
                of: #"\s*"(animations\.)?on_reveal" : (true|false),"#,
                with: "",
                options: .regularExpression
            )
        #expect(!text.contains("on_reveal"))
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(text.utf8))
                as? [String: Any]
        )
        root["format"] = format
        return try JSONSerialization.data(withJSONObject: root)
    }

    private var look: LookBody { LookBody(of: tuned) }

    private func profile(format: Int) -> Profile {
        Profile(
            format: format,
            name: "Work",
            monitorSets: [],
            spaceModes: [:],
            settings: tuned
        )
    }

    private func check(_ animations: AnimationSettings) {
        #expect(!animations.onReveal)
        #expect(animations.revealDurationMS == 300)
        #expect(!animations.onExpand)
        #expect(animations.expandDurationMS == 750)
    }

    private func checkLook(_ body: LookBody?) throws {
        let style = try #require(body?.style)
        #expect(style["animations.reveal_duration"] == .number(300))
        #expect(style["animations.on_reveal"] == .bool(false))
        #expect(style["animations.expand_duration"] == .number(750))
        #expect(style["animations.on_expand"] == .bool(false))
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        _ node: Any?
    ) throws -> T {
        try decoder.decode(
            T.self,
            from: JSONSerialization.data(withJSONObject: try #require(node))
        )
    }

    private func root(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    @Test("a profile's 0 lengths become the switches off")
    func profileCrosses() throws {
        let data = try legacy(profile(format: 36), format: 36)
        let out = try root(#require(ConfigMigration.migrated(data)))
        check(try decode(TilingSettings.self, out["settings"]).animations)
        #expect(out["format"] as? Int == Profile.currentFormat)
    }

    @Test("without the step the decoder reads a 0 as the floor")
    func decoderAloneAnimates() throws {
        let data = try legacy(profile(format: 36), format: 36)
        let raw = try root(data)
        let settings = try decode(TilingSettings.self, raw["settings"])
        #expect(settings.animations.onReveal)
        #expect(settings.animations.revealDurationMS == 150)
    }

    @Test("the shared look in gui.json crosses")
    func sharedLookCrosses() throws {
        var config = GuiConfig()
        config.look = look
        let data = try legacy(config, format: 21)
        let out = try #require(ConfigMigration.migrated(data))
        try checkLook(decoder.decode(GuiConfig.self, from: out).look)
    }

    @Test("the look library crosses")
    func libraryCrosses() throws {
        let document = LookDocument(format: 3, looks: [look.named("Mine")])
        let data = try legacy(document, format: 3)
        let out = try #require(ConfigMigration.migrated(data))
        let back = try decoder.decode(LookDocument.self, from: out)
        try checkLook(
            back.looks.first.map {
                LookBody(style: $0.style, colors: $0.colors)
            }
        )
    }

    @Test("a backup's profiles, shared look and looks cross")
    func bundleCrosses() throws {
        var config = GuiConfig()
        config.look = look
        let bundle = SetupBundle(
            format: 45,
            writtenBy: "test",
            config: config,
            profiles: [profile(format: 36)],
            palettes: [],
            looks: [look.named("Mine")]
        )
        let out = try root(
            #require(ConfigMigration.migrated(legacy(bundle, format: 45)))
        )
        let profiles = try #require(out["profiles"] as? [[String: Any]])
        check(
            try decode(TilingSettings.self, profiles.first?["settings"])
                .animations
        )
        try checkLook(decode(GuiConfig.self, out["config"]).look)
        let looks = try decode([ShelfLook].self, out["looks"])
        try checkLook(
            looks.first.map {
                LookBody(style: $0.style, colors: $0.colors)
            }
        )
    }

    @Test("the edit is surgical: only the two values move")
    func editIsSurgical() throws {
        let data = try legacy(profile(format: 36), format: 36)
        let text = try #require(String(data: data, encoding: .utf8))
        let out = try #require(
            ConfigMigration.migratingInstantDurationsOntoToggles(data)
        )
        let edited = try #require(String(data: out, encoding: .utf8))
        let expected =
            text
            .replacingOccurrences(
                of: "\"expand_duration\":0",
                with: "\"expand_duration\":750"
            )
            .replacingOccurrences(
                of: "\"on_expand\":true",
                with: "\"on_expand\":false"
            )
            .replacingOccurrences(
                of: "\"reveal_duration\":0",
                with: "\"reveal_duration\":300, \"on_reveal\": false"
            )
        #expect(edited == expected)
    }

    @Test("a file with no 0 is left alone")
    func inBandStaysPut() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile(format: 36))
        #expect(
            ConfigMigration.migratingInstantDurationsOntoToggles(data)
                == nil
        )
    }

    @Test("0 and below are instant, a Bool false is not")
    func instantReading() {
        #expect(!ConfigMigration.isStoredInstant(false))
        #expect(ConfigMigration.isStoredInstant(0))
        #expect(ConfigMigration.isStoredInstant(-5))
        #expect(!ConfigMigration.isStoredInstant(300))
    }

    /// An older look's style map carries a reveal length and no
    /// switch, which meant the reveal plays; the step writes that
    /// down, so it still plays over a profile the step turned off.
    @Test("an older look's in-band reveal keeps playing")
    func lookAbsenceCrosses() throws {
        var settings = TilingSettings()
        settings.animations.revealDurationMS = 450
        let style = LookKeys.extract(from: settings)
        #expect(style["animations.on_reveal"] != nil)
        var old = style
        old["animations.on_reveal"] = nil
        let document = LookDocument(
            format: 3,
            looks: [ShelfLook(name: "Old", style: old, colors: [:])]
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(document)
        let out = try #require(
            ConfigMigration.migratingInstantDurationsOntoToggles(data)
        )
        let back = try decoder.decode(LookDocument.self, from: out)
        let crossed = try #require(back.looks.first?.style)
        #expect(crossed["animations.on_reveal"] == .bool(true))
        #expect(crossed["animations.reveal_duration"] == .number(450))
    }

    @Test("an exported look file crosses on import")
    func lookExportCrosses() throws {
        let document = LookDocument(format: 3, looks: [look.named("Mine")])
        let data = try legacy(document, format: 3)
        let crossed = ConfigMigration.crossingLookExport(data, from: 3)
        let back = try decoder.decode(LookDocument.self, from: crossed)
        try checkLook(
            back.looks.first.map {
                LookBody(style: $0.style, colors: $0.colors)
            }
        )
    }

    /// The look insert keeps the file's bytes: only the new switch
    /// lands, right after its length.
    @Test("the look insert is surgical")
    func lookInsertIsSurgical() throws {
        var settings = TilingSettings()
        settings.animations.revealDurationMS = 450
        var style = LookKeys.extract(from: settings)
        style["animations.on_reveal"] = nil
        let document = LookDocument(
            format: 3,
            looks: [ShelfLook(name: "Old", style: style, colors: [:])]
        )
        let data = try JSONEncoder().encode(document)
        let text = try #require(String(data: data, encoding: .utf8))
        let needle = "\"animations.reveal_duration\":450"
        #expect(text.contains(needle))
        let out = try #require(
            ConfigMigration.migratingInstantDurationsOntoToggles(data)
        )
        let expected = text.replacingOccurrences(
            of: needle,
            with: needle + ", \"animations.on_reveal\": true"
        )
        #expect(String(data: out, encoding: .utf8) == expected)
    }
}
