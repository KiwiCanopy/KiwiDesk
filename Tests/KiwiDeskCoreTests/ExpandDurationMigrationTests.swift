import Foundation
import Testing

@testable import KiwiDeskCore

/// `animations.on_shelf` / `shelf_duration` become `on_expand` /
/// `expand_duration` (owner ruling, 2026-10-21), in every shape that
/// carries them: a profile's settings, `gui.json`'s shared look,
/// `looks.json` and a backup's inline copies of all three. Fixtures
/// are the encoder's own output with the retired names put back,
/// never hand-typed JSON.
@Suite("Expand duration migration")
struct ExpandDurationMigrationTests {
    /// `value` encoded, then each live name spelled as the older
    /// build wrote it, the look paths included.
    private func legacy<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let text = try #require(
            String(data: encoder.encode(value), encoding: .utf8)
        )
        #expect(text.contains("expand_duration\""))
        let old =
            text
            .replacingOccurrences(
                of: "expand_duration\"",
                with: "shelf_duration\""
            )
            .replacingOccurrences(of: "on_expand\"", with: "on_shelf\"")
        return Data(old.utf8)
    }

    /// Settings whose expand is tuned away from every default.
    private var tuned: TilingSettings {
        var settings = TilingSettings()
        settings.animations.onExpand = false
        settings.animations.expandDurationMS = 1250
        return settings
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
        #expect(!animations.onExpand)
        #expect(animations.expandDurationMS == 1250)
    }

    private func checkLook(_ body: LookBody?) throws {
        let style = try #require(body?.style)
        #expect(style["animations.expand_duration"] == .number(1250))
        #expect(style["animations.on_expand"] == .bool(false))
        #expect(style["animations.shelf_duration"] == nil)
    }

    private func migrated(_ data: Data) throws -> Data {
        let out = try #require(ConfigMigration.migrated(data))
        let text = try #require(String(data: out, encoding: .utf8))
        #expect(!text.contains("shelf_duration"))
        #expect(!text.contains("on_shelf"))
        return out
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// `root[key]` decoded as `T`.
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

    @Test("a profile's tuned expand moves to the new keys")
    func profileMoves() throws {
        let out = try root(migrated(legacy(profile(format: 27))))
        check(try decode(TilingSettings.self, out["settings"]).animations)
        #expect(out["format"] as? Int == Profile.currentFormat)
    }

    @Test("the shared look in gui.json crosses")
    func sharedLookMoves() throws {
        var config = GuiConfig()
        config.look = look
        let data = try legacy(config)
        let out = try migrated(restamp(data, to: 12))
        let back = try decoder.decode(GuiConfig.self, from: out)
        try checkLook(back.look)
    }

    @Test("the look library crosses")
    func libraryMoves() throws {
        let document = LookDocument(
            format: 1,
            looks: [look.named("Mine")]
        )
        let out = try migrated(legacy(document))
        let back = try decoder.decode(LookDocument.self, from: out)
        try checkLook(
            back.looks.first.map {
                LookBody(style: $0.style, colors: $0.colors)
            }
        )
    }

    @Test("a backup's profiles, shared look and looks cross")
    func bundleMoves() throws {
        var config = GuiConfig()
        config.look = look
        let bundle = SetupBundle(
            format: 34,
            writtenBy: "test",
            config: config,
            profiles: [profile(format: 27)],
            palettes: [],
            looks: [look.named("Mine")]
        )
        let out = try root(migrated(legacy(bundle)))
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

    @Test("the retired verbs name their replacements")
    func verbsRetire() {
        #expect(
            APIReference.retirement(of: "animations.set_on_shelf")?
                .contains("animations.set_on_expand") == true
        )
        #expect(
            APIReference.retirement(of: "animations.set_shelf_duration")?
                .contains("animations.set_expand_duration") == true
        )
    }

    /// `data` with its root `format` set to `format`.
    private func restamp(_ data: Data, to format: Int) throws -> Data {
        var root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        root["format"] = format
        return try JSONSerialization.data(withJSONObject: root)
    }
}
