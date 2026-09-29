import Foundation
import Testing

@testable import KiwiDeskCore

/// A backup's looks take in their palettes' colours below bundle
/// format 17 (#1752): the bundle's own inline palettes first, then
/// the bundled ones, else the shipped colours. The old looks are
/// written by their own encoder (`PaletteNamedLook`).
@Suite("Look colour bundle migration")
struct LookColorBundleMigrationTests {
    private let theirs = ColorPalette(
        name: "Theirs",
        colors: ["kiwishelf.fill_color": "#123456"]
    )

    /// A current bundle re-shaped into the format-16 one: its looks
    /// naming palettes, its stamp one below the crossing.
    private func legacyBundle(_ looks: [PaletteNamedLook]) throws -> Data {
        let current = SetupBundle(
            writtenBy: "test",
            config: nil,
            profiles: [],
            palettes: [theirs],
            looks: nil
        )
        var root = try #require(
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(current)
            ) as? [String: Any]
        )
        root["format"] = ConfigMigration.lookColorsBundleFormat - 1
        root["looks"] = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(looks)
        )
        return try JSONSerialization.data(withJSONObject: root)
    }

    private func named(
        _ name: String,
        _ palette: String?
    ) -> PaletteNamedLook {
        PaletteNamedLook(
            name: name,
            palette: palette,
            style: ["kiwishelf.thickness": .number(30)]
        )
    }

    @Test("a bundle's looks take their palettes' colours")
    func looksTakeColours() throws {
        let slate = try #require(
            PaletteCatalog.bundled().first { $0.name == "Slate" }
        )
        let data = try legacyBundle([
            named("A", "Theirs"), named("B", "Slate"), named("C", "Gone"),
        ])
        let migrated = try #require(ConfigMigration.migrated(data))
        let bundle = try JSONDecoder().decode(
            SetupBundle.self,
            from: migrated
        )
        #expect(bundle.format == SetupBundle.currentFormat)
        #expect(
            bundle.looks?.map(\.colors) == [
                theirs.paintedColors,
                slate.paintedColors,
                PaletteCatalog.defaultPalette().paintedColors,
            ]
        )
        #expect(bundle.looks?.first?.style == named("A", nil).style)
    }

    @Test("a bundle at the crossing's format is left alone")
    func currentBundleUntouched() throws {
        var root = try #require(
            try JSONSerialization.jsonObject(
                with: legacyBundle([named("A", "Theirs")])
            ) as? [String: Any]
        )
        root["format"] = ConfigMigration.lookColorsBundleFormat
        let data = try JSONSerialization.data(withJSONObject: root)
        #expect(ConfigMigration.migratingBundleLookColors(data) == nil)
    }
}
