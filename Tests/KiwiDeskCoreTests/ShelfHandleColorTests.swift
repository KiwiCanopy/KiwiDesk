import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The resting handle's colour (#3357): `kiwishelf.handle_color`,
/// empty for Automatic — the label ink at `restAlpha` — taken by
/// the verb, the decoder and a palette, and left out of every
/// bundled palette.
@Suite("Shelf handle colour (#3357)")
struct ShelfHandleColorTests {
    @Test("Automatic is the default, and absent decodes to it")
    func defaultIsAutomatic() throws {
        #expect(KiwiShelf().handleColor.isEmpty)
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data("{}".utf8)
        )
        #expect(shelf.handleColor.isEmpty)
    }

    @Test("A set colour round-trips under handle_color")
    func roundTrips() throws {
        var shelf = KiwiShelf()
        shelf.handleColor = "#FF000080"
        let data = try JSONEncoder().encode(shelf)
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(root["handle_color"] as? String == "#FF000080")
        let back = try JSONDecoder().decode(KiwiShelf.self, from: data)
        #expect(back.handleColor == "#FF000080")
    }

    @Test("The verb takes a hex or Automatic, and refuses the rest")
    func verbTakesAutomatic() {
        func parse(_ field: String, _ value: String) -> Bool {
            if case .success = KiwiShelfCommandSetting.parse(
                field: field,
                args: [.string(value)]
            ) {
                return true
            }
            return false
        }
        #expect(parse("handle_color", "#8DB354"))
        #expect(parse("handle_color", ""))
        #expect(!parse("handle_color", "moss"))
        // An ordinary shelf colour still refuses the empty value.
        #expect(!parse("item_color", ""))
        var shelf = KiwiShelf()
        shelf.handleColor = "#8DB354"
        if case .success(let setting) = KiwiShelfCommandSetting.parse(
            field: "handle_color",
            args: [.string("")]
        ) {
            setting.apply(to: &shelf)
        }
        #expect(shelf.handleColor.isEmpty)
    }

    @Test("A palette paints it and hands it back to Automatic")
    func paletteRoundTrips() {
        #expect(ColorPaletteKeys.allowsAutomatic("kiwishelf.handle_color"))
        var settings = TilingSettings()
        ColorPalette(
            name: "H",
            colors: ["kiwishelf.handle_color": "#4A9816"]
        ).apply(to: &settings)
        #expect(settings.kiwishelf.handleColor == "#4A9816")
        ColorPalette(
            name: "A",
            colors: ["kiwishelf.handle_color": ""]
        ).apply(to: &settings)
        #expect(settings.kiwishelf.handleColor.isEmpty)
    }

    /// Ruling 3: a bundled palette shows Automatic for every
    /// `adaptive` colour. The derived default palette carries
    /// every path, these empty.
    @Test("No bundled palette sets an adaptive colour")
    func bundledPalettesLeaveItOut() {
        #expect(ColorPaletteKeys.adaptive.contains("kiwishelf.handle_color"))
        for palette in PaletteCatalog.bundled() {
            for path in ColorPaletteKeys.adaptive
            where !(palette.colors[path] ?? "").isEmpty {
                Issue.record("\(palette.name) sets \(path)")
            }
        }
    }

    @Test("Automatic is the label ink at restAlpha in either mode")
    @MainActor
    func automaticFollowsTheAppearance() throws {
        func resolved(_ hex: String, _ name: NSAppearance.Name)
            throws -> NSColor
        {
            let appearance = try #require(NSAppearance(named: name))
            var color = NSColor.clear
            appearance.performAsCurrentDrawingAppearance {
                let cg = ShelfHandleSpec.restColor(hex: hex).cgColor
                color = NSColor(cgColor: cg) ?? .clear
            }
            return color.usingColorSpace(.sRGB) ?? color
        }
        let light = try resolved("", .aqua)
        let dark = try resolved("", .darkAqua)
        #expect(abs(light.alphaComponent - ShelfHandleSpec.restAlpha) < 0.02)
        #expect(abs(dark.alphaComponent - ShelfHandleSpec.restAlpha) < 0.02)
        // Dark ink on light, light ink on dark.
        #expect(light.redComponent < 0.5)
        #expect(dark.redComponent > 0.5)
        let set = try resolved("#FF000080", .darkAqua)
        #expect(abs(set.redComponent - 1) < 0.01)
        #expect(set.greenComponent < 0.01)
        #expect(abs(set.alphaComponent - 128.0 / 255) < 0.01)
    }
}
