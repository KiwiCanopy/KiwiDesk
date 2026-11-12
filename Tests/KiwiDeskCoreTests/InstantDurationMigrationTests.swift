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
    /// The type's own settings: since #3237 it encodes no length,
    /// so `legacy` writes the older build's 0s back in.
    private var tuned: TilingSettings { TilingSettings() }

    /// `value` encoded, then put back in the older build's shape:
    /// no reveal switch (it is new), each length a 0 in the
    /// profile's `animations` and in a look's style map, and
    /// `format` stamped.
    private func legacy<T: Encodable>(
        _ value: T,
        format: Int
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var root = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(value))
                as? [String: Any]
        )
        root = try #require(Self.oldShape(root) as? [String: Any])
        root["format"] = format
        let data = try JSONSerialization.data(withJSONObject: root)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.contains("on_reveal"))
        #expect(text.contains("reveal_duration\":0"))
        return data
    }

    /// Every profile `animations` object and look style map, as
    /// the build before #3236 wrote it.
    private static func oldShape(_ node: Any) -> Any {
        if var dict = node as? [String: Any] {
            for (key, value) in dict { dict[key] = oldShape(value) }
            for prefix in ["", "animations."]
            where dict[prefix + "on_window_swap"] != nil {
                dict[prefix + "on_reveal"] = nil
                dict[prefix + "reveal_duration"] = 0
                dict[prefix + "expand_duration"] = 0
            }
            return dict
        }
        if let array = node as? [Any] { return array.map(oldShape) }
        return node
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

    /// A profile's raw `settings.animations` after the step: both
    /// switches off, both lengths at their defaults.
    private func check(_ settings: Any?) throws {
        let animations = try #require(
            (settings as? [String: Any])?["animations"] as? [String: Any]
        )
        #expect(animations["on_reveal"] as? Bool == false)
        #expect(animations["reveal_duration"] as? Int == 300)
        #expect(animations["on_expand"] as? Bool == false)
        #expect(animations["expand_duration"] as? Int == 750)
    }

    /// A look after the full migration: both switches off, and no
    /// length, which #3237's step strips.
    private func checkLook(_ body: LookBody?) throws {
        let style = try #require(body?.style)
        #expect(style["animations.on_reveal"] == .bool(false))
        #expect(style["animations.on_expand"] == .bool(false))
        #expect(style["animations.reveal_duration"] == nil)
        #expect(style["animations.expand_duration"] == nil)
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
        try check(out["settings"])
        #expect(out["format"] as? Int == Profile.currentFormat)
    }

    /// #3237's capture reads the migrated bytes, so a 0 is adopted
    /// as the switch off at the default length, never as the floor
    /// (profiles.md).
    @Test("the app-wide capture reads the crossed length")
    func captureReadsTheCrossing() throws {
        let data = try legacy(profile(format: 36), format: 36)
        let pace = try #require(ConfigMigration.legacyPace(inProfile: data))
        #expect(pace.revealDuration == 300)
        #expect(pace.expandDuration == 750)
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
        try check(profiles.first?["settings"])
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
        var old = LookKeys.extract(from: TilingSettings())
        #expect(old["animations.on_reveal"] != nil)
        old["animations.on_reveal"] = nil
        old["animations.reveal_duration"] = .number(450)
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
        var style = LookKeys.extract(from: TilingSettings())
        style["animations.on_reveal"] = nil
        style["animations.reveal_duration"] = .number(450)
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
