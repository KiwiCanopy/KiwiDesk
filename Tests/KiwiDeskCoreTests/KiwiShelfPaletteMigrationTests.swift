import Foundation
import Testing

@testable import KiwiDeskCore

/// A palette's bar colours become the shelf's (#1517): the Space
/// Bar's win, its dimmed idle ink resolves to the App Bar's full
/// colour, every bar copy drops and the Space Bar's own
/// focused-window ink stays. `palettes.json` crosses at format 2,
/// a bundle's inline palettes below the bundle's shelf format,
/// and the stampless exported sidecar in memory on import.
@Suite("KiwiShelf palette migration (#1517)")
struct KiwiShelfPaletteMigrationTests {
    private static let barColors: [String: String] = [
        "app_bar.fill_color": "#101010B3",
        "app_bar.item_color": "#EAF3EE",
        "app_bar.highlight_color": "#00FF00",
        "space_bar.fill_color": "#202020B3",
        "space_bar.item_color": "#EAF3EE66",
        "space_bar.focused_item_color": "#C2790A",
        "border.focused_color": "#4A9816",
    ]

    @Test("the Space Bar's colours become the shelf's")
    func spaceBarWins() {
        let out = ConfigMigration.shelvedPaletteColors(Self.barColors)
        #expect(out["kiwishelf.fill_color"] == "#202020B3")
        // Only the App Bar set it: it is the one there is.
        #expect(out["kiwishelf.highlight_color"] == "#00FF00")
        #expect(out["space_bar.focused_item_color"] == "#C2790A")
        #expect(out["border.focused_color"] == "#4A9816")
        for key in out.keys {
            #expect(
                !key.hasPrefix("app_bar."),
                Comment(rawValue: key)
            )
        }
        #expect(out["space_bar.fill_color"] == nil)
        #expect(out["space_bar.item_color"] == nil)
    }

    /// The idle rule dims now; keeping the dimmed value would dim
    /// twice.
    @Test("a dimmed twin resolves to the full colour")
    func dimmedTwinTakesTheFullColour() {
        let out = ConfigMigration.shelvedPaletteColors(Self.barColors)
        #expect(out["kiwishelf.item_color"] == "#EAF3EE")
    }

    /// A different hue is a choice, not a dimming: the Space Bar
    /// wins it as it wins every other colour.
    @Test("a different hue is not a twin")
    func differentHueKeepsTheSpaceBar() {
        var colors = Self.barColors
        colors["space_bar.item_color"] = "#FF000066"
        let out = ConfigMigration.shelvedPaletteColors(colors)
        #expect(out["kiwishelf.item_color"] == "#FF000066")
        #expect(!ConfigMigration.isDimmedTwin("#EAF3EE", of: "#EAF3EE"))
        #expect(!ConfigMigration.isDimmedTwin("#EAF3EEFF", of: "#EAF3EE66"))
    }

    @Test("a shelved map is left alone")
    func idempotent() {
        let once = ConfigMigration.shelvedPaletteColors(Self.barColors)
        #expect(ConfigMigration.shelvedPaletteColors(once) == once)
    }

    @Test("palettes.json crosses below format 2 and stands down at it")
    func libraryCrossesOnce() throws {
        let colors = try JSONSerialization.data(
            withJSONObject: Self.barColors
        )
        let body = try #require(String(data: colors, encoding: .utf8))
        let below = Data(
            """
            {"format":1,"palettes":[{"colors":\(body),"name":"Mine"}]}
            """.utf8
        )
        let out = try #require(ConfigMigration.migrated(below))
        let decoded = try JSONDecoder().decode(
            PaletteDocument.self,
            from: out
        )
        #expect(decoded.format == PaletteDocument.currentFormat)
        let palette = try #require(decoded.palettes.first)
        #expect(palette.colors["kiwishelf.fill_color"] == "#202020B3")
        #expect(palette.colors["app_bar.fill_color"] == nil)
        let at = Data(
            """
            {"format":\(ConfigMigration.shelfPaletteFormat),\
            "palettes":[{"colors":\(body),"name":"Mine"}]}
            """.utf8
        )
        #expect(ConfigMigration.migratingPalettesOntoShelf(at) == nil)
    }

    @Test("a bundle's inline palettes cross below its shelf format")
    func bundlePalettesCross() throws {
        let colors = try JSONSerialization.data(
            withJSONObject: Self.barColors
        )
        let body = try #require(String(data: colors, encoding: .utf8))
        let bundle = Data(
            """
            {"format":\(ConfigMigration.shelfBundleFormat - 1),\
            "writtenBy":"KiwiDesk","config":{},"profiles":[],\
            "palettes":[{"colors":\(body),"name":"Mine"}]}
            """.utf8
        )
        let out = try #require(
            ConfigMigration.migratingPalettesOntoShelf(bundle)
        )
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let palettes = try #require(
            root["palettes"] as? [[String: Any]]
        )
        let shelved = try #require(
            palettes.first?["colors"] as? [String: String]
        )
        #expect(shelved["kiwishelf.item_color"] == "#EAF3EE")
    }

    /// The sidecar is never rewritten on disk, so its import is
    /// where the crossing reaches it.
    @Test("an exported sidecar is shelved on import")
    func sidecarImportShelves() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwishelf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("Mine.json")
        let old = ColorPalette(name: "Mine", colors: Self.barColors)
        try JSONEncoder().encode(old).write(to: file)
        let imported = try PaletteStore(directory: dir)
            .importPalette(from: file)
        #expect(imported.colors["kiwishelf.fill_color"] == "#202020B3")
        #expect(imported.colors["kiwishelf.item_color"] == "#EAF3EE")
        #expect(imported.colors["app_bar.fill_color"] == nil)
    }
}

/// The profile walk and the palette path agree: a shelf that
/// already holds an item colour keeps it, the dimmed-twin rule
/// only filling an absent one (#1517 review).
@Suite("KiwiShelf crossing keeps a held item colour")
struct KiwiShelfHeldItemColorTests {
    @Test("A held shelf item colour survives the twin rule")
    func heldItemColorKept() throws {
        let data = Data(
            """
            {"format":7,"monitor_sets":[],"name":"A","settings":{\
            "kiwishelf":{"item_color":"#123456"},\
            "app_bar":{"item_color":"#EAF3EE"},\
            "space_bar":{"item_color":"#EAF3EE66"}}}
            """.utf8
        )
        let out = try #require(ConfigMigration.migrated(data))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let settings = try #require(root["settings"] as? [String: Any])
        let shelf = try #require(settings["kiwishelf"] as? [String: Any])
        #expect(shelf["item_color"] as? String == "#123456")
    }
}
