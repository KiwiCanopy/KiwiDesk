import Foundation
import Testing

@testable import KiwiDeskCore

/// A stored colour set wearing a bundled palette with its handle
/// Automatic takes that palette's handle colour (#3409), in every
/// shape that stores one, from the formats 4.2.1 stamped; a set
/// that differs elsewhere stays custom. Fixtures are the encoder's
/// own output, the handle removed where a pre-#3357 file had none.
@Suite("Handle stamp migration (#3409)")
struct HandleStampMigrationTests {
    private static let handle = "kiwishelf.handle_color"

    /// 5.0's frozen Slate, the step's own copy of it.
    private var slate: [String: String] {
        ConfigMigration.handleStampPalettes
            .first { $0.name == "Slate" }?.colors ?? [:]
    }

    /// Settings wearing `colors` with the handle left Automatic.
    private func wearing(_ colors: [String: String]) -> TilingSettings {
        var settings = TilingSettings()
        var unpainted = colors
        unpainted[Self.handle] = ""
        ColorPalette(name: "", colors: unpainted).apply(to: &settings)
        return settings
    }

    /// Slate with its handle Automatic: a user palette that copied
    /// it, which stays the user's.
    private var unstamped: [String: String] {
        var colors = slate
        colors[Self.handle] = ""
        return colors
    }

    private var custom: TilingSettings {
        var settings = wearing(slate)
        settings.borderStyle.focusedColor = "#123456"
        return settings
    }

    /// The encoder's bytes at `format`; `absent` drops every handle
    /// key, as a file written before #3357 has none.
    private func stamped<T: Encodable>(
        _ value: T,
        format: Int,
        absent: Bool
    ) throws -> Data {
        var root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(value)
            ) as? [String: Any]
        )
        root["format"] = format
        let node = absent ? Self.dropped(root) : root
        return try JSONSerialization.data(
            withJSONObject: node,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private static func dropped(_ node: Any) -> Any {
        if var dict = node as? [String: Any] {
            dict["handle_color"] = nil
            dict[handle] = nil
            for (key, value) in dict { dict[key] = dropped(value) }
            return dict
        }
        if let array = node as? [Any] { return array.map(dropped) }
        return node
    }

    private func profile(_ settings: TilingSettings) -> Profile {
        Profile(
            name: "Work",
            monitorSets: [],
            spaceModes: [:],
            settings: settings
        )
    }

    private func config(_ settings: TilingSettings) -> GuiConfig {
        var config = GuiConfig()
        config.look = LookBody(of: settings)
        return config
    }

    private func look(_ settings: TilingSettings) -> ShelfLook {
        ShelfLook(
            name: "Mine",
            style: [:],
            colors: ColorPaletteKeys.extract(from: settings)
        )
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    /// A migrated profile's settings: a fixture profile carries no
    /// monitor set, which `Profile`'s decoder refuses.
    private func settings(_ data: Data?) throws -> TilingSettings {
        let root = try object(#require(data))
        return try decode(TilingSettings.self, #require(root["settings"]))
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        _ node: Any
    ) throws -> T {
        try JSONDecoder().decode(
            type,
            from: JSONSerialization.data(withJSONObject: node)
        )
    }

    /// From 4.2.1's profile stamp (34), so every later step runs.
    @Test(
        "a profile wearing a bundled palette is stamped",
        arguments: [true, false]
    )
    func profileCrosses(absent: Bool) throws {
        let glass = TilingSettings()
        let data = try stamped(profile(glass), format: 34, absent: absent)
        let read = try settings(ConfigMigration.migrated(data))
        #expect(
            read.kiwishelf.handleColor == glass.kiwishelf.activeItemColor
        )
        #expect(PaletteCatalog.defaultPalette().isApplied(to: read))

        let slated = try stamped(
            profile(wearing(slate)),
            format: 34,
            absent: absent
        )
        let other = try settings(ConfigMigration.migrated(slated))
        #expect(
            other.kiwishelf.handleColor
                == slate["kiwishelf.active_item_color"]
        )
    }

    /// A set off by one colour stays custom, including a path only
    /// the default palette lists (the floating mark's).
    @Test("a custom set stays custom", arguments: [true, false])
    func customStays(absent: Bool) throws {
        var floating = TilingSettings()
        floating.floatingStyle.color = "#112233"
        for settings in [custom, floating] {
            let data = try stamped(
                profile(settings),
                format: 34,
                absent: absent
            )
            let read = try self.settings(ConfigMigration.migrated(data))
            #expect(read.kiwishelf.handleColor.isEmpty)
        }
    }

    /// A handle the user painted is theirs, palette or not.
    @Test("a painted handle stays")
    func paintedStays() throws {
        var painted = wearing(slate)
        painted.kiwishelf.handleColor = "#FF0000"
        let data = try stamped(profile(painted), format: 34, absent: false)
        let read = try settings(ConfigMigration.migrated(data))
        #expect(read.kiwishelf.handleColor == "#FF0000")
    }

    /// From 4.2.1's gui stamp (19): the shared look's map.
    @Test("gui.json's shared look is stamped", arguments: [true, false])
    func guiCrosses(absent: Bool) throws {
        let data = try stamped(
            config(TilingSettings()),
            format: 19,
            absent: absent
        )
        let out = try #require(ConfigMigration.migrated(data))
        let read = try JSONDecoder().decode(GuiConfig.self, from: out)
        let colors = try #require(read.look?.colors)
        #expect(
            colors[Self.handle]
                == TilingSettings().kiwishelf.activeItemColor
        )
    }

    /// A map that never stored the accent chose no palette.
    @Test("a set without the accent is left alone")
    func noAccentStays() throws {
        var colors = ColorPaletteKeys.extract(from: TilingSettings())
        colors["kiwishelf.active_item_color"] = nil
        var config = GuiConfig()
        config.look = LookBody(style: [:], colors: colors)
        let gui = try stamped(config, format: 19, absent: true)
        let read = try JSONDecoder().decode(
            GuiConfig.self,
            from: #require(ConfigMigration.migrated(gui))
        )
        #expect(try #require(read.look).colors[Self.handle] == nil)
        let library = LookDocument(
            looks: [ShelfLook(name: "Bare", style: [:], colors: colors)]
        )
        let data = try stamped(library, format: 3, absent: true)
        let looks = try JSONDecoder().decode(
            LookDocument.self,
            from: #require(ConfigMigration.migrated(data))
        ).looks
        #expect(try #require(looks.first).colors[Self.handle] == nil)
    }

    /// From 4.2.1's library stamp (3): a saved look's map, a custom
    /// one beside it left alone.
    @Test("looks.json's saved looks are stamped")
    func libraryCrosses() throws {
        let document = LookDocument(
            looks: [look(wearing(slate)), look(custom)]
        )
        let data = try stamped(document, format: 3, absent: true)
        let out = try #require(ConfigMigration.migrated(data))
        let read = try JSONDecoder().decode(LookDocument.self, from: out)
        #expect(
            read.looks.first?.colors[Self.handle]
                == slate["kiwishelf.active_item_color"]
        )
        #expect(read.looks.count == 2)
        #expect(try #require(read.looks.last).colors[Self.handle] == nil)
    }

    /// From 4.2.1's backup stamp (43): its shared look, its profiles
    /// and its looks; its palette library is never stamped.
    @Test("a backup's every copy is stamped", arguments: [true, false])
    func bundleCrosses(absent: Bool) throws {
        let glass = TilingSettings()
        let bundle = SetupBundle(
            format: 43,
            writtenBy: "test",
            config: config(glass),
            profiles: [profile(wearing(slate)), profile(custom)],
            palettes: [ColorPalette(name: "Mine", colors: unstamped)],
            looks: [look(glass)]
        )
        let data = try stamped(bundle, format: 43, absent: absent)
        let root = try object(#require(ConfigMigration.migrated(data)))
        let shared = try decode(GuiConfig.self, #require(root["config"]))
        #expect(
            shared.look?.colors[Self.handle]
                == glass.kiwishelf.activeItemColor
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        let own = try profiles.map {
            try decode(TilingSettings.self, #require($0["settings"]))
        }
        #expect(
            own.first?.kiwishelf.handleColor
                == slate["kiwishelf.active_item_color"]
        )
        #expect(own.last?.kiwishelf.handleColor == "")
        let palettes = try decode(
            [ColorPalette].self,
            #require(root["palettes"])
        )
        let mine = try #require(palettes.first)
        #expect(mine.colors[Self.handle] ?? "" == "")
        let looks = try decode([ShelfLook].self, #require(root["looks"]))
        #expect(
            looks.first?.colors[Self.handle]
                == glass.kiwishelf.activeItemColor
        )
    }

    /// An exported look file crosses in memory, through
    /// `lookExportSteps`.
    @Test("an exported look is stamped on import")
    func exportCrosses() throws {
        let export = LookExport(look: look(TilingSettings()))
        let data = try stamped(export, format: 3, absent: true)
        let out = ConfigMigration.crossingLookExport(data, from: 3)
        let read = try JSONDecoder().decode(LookExport.self, from: out)
        #expect(
            read.look.colors[Self.handle]
                == TilingSettings().kiwishelf.activeItemColor
        )
        // At the format it introduced the entry stands down.
        #expect(ConfigMigration.crossingLookExport(data, from: 6) == data)
    }

    /// At the formats it introduced the step stands down, so an
    /// Automatic handle set after the crossing is the user's.
    @Test("the step stands down at its own formats")
    func standsDown() throws {
        let floors: [(Encodable, Int)] = [
            (
                profile(TilingSettings()),
                ConfigMigration.handleStampProfileFormat
            ),
            (
                config(TilingSettings()),
                ConfigMigration.handleStampGuiFormat
            ),
            (
                LookDocument(looks: [look(TilingSettings())]),
                ConfigMigration.handleStampLookFormat
            ),
        ]
        for (value, format) in floors {
            let data = try stamped(value, format: format, absent: false)
            #expect(ConfigMigration.migratingHandleStamp(data) == nil)
        }
        let bundle = SetupBundle(
            format: ConfigMigration.handleStampBundleFormat,
            writtenBy: "test",
            config: config(TilingSettings()),
            profiles: [profile(TilingSettings())],
            palettes: []
        )
        let data = try stamped(
            bundle,
            format: ConfigMigration.handleStampBundleFormat,
            absent: false
        )
        #expect(ConfigMigration.migratingHandleStamp(data) == nil)
    }

    /// The edit writes the stamp into the file's own text, so a
    /// spacing the walk would not keep survives.
    @Test("the edit is surgical")
    func editIsSurgical() throws {
        let text = String(
            decoding: try stamped(
                profile(TilingSettings()),
                format: 34,
                absent: true
            ),
            as: UTF8.self
        )
        .replacingOccurrences(of: "\"format\" : ", with: "\"format\" :  ")
        let edited = try #require(ConfigMigration.handleStampText(text))
        #expect(
            ConfigMigration.migratingHandleStamp(Data(text.utf8)) == edited
        )
        #expect(
            String(decoding: edited, as: UTF8.self)
                .contains("\"format\" :  ")
        )
    }
}
