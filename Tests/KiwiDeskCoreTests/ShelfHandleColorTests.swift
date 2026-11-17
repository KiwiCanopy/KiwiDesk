import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The handle's colour (#3357, #3360): `kiwishelf.handle_color`,
/// empty for Automatic — the label ink at the rest and fill
/// strengths — taken by the verb, the decoder and a palette, and
/// painted by every bundled palette in its accent (#3377).
@Suite("Shelf handle colour (#3357, #3360)")
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

    /// #3377 ruling 1: every bundled palette, the derived default
    /// included, paints the handle in its own accent.
    @Test("Every bundled palette paints the handle in its accent")
    func bundledPalettesPaintTheAccent() {
        #expect(ColorPaletteKeys.adaptive.contains("kiwishelf.handle_color"))
        #expect(KiwiShelf().handleColor.isEmpty)
        #expect(
            Set(ColorPaletteKeys.bundledPaint.keys)
                == ColorPaletteKeys.adaptive
        )
        for palette in PaletteCatalog.bundled() {
            for (path, source) in ColorPaletteKeys.bundledPaint {
                let paint = palette.colors[path]
                let name = Comment(rawValue: "\(palette.name) \(path)")
                #expect(paint != nil, name)
                #expect(paint == palette.colors[source], name)
            }
        }
    }

    /// The core-vs-hairline lightness gate (#3377 ruling 3). The
    /// hairline takes the tone opposite the core's encoded luma, so
    /// their opaque distance is at least 0.5 by construction; the
    /// risk is a core near the 0.5 pivot, where a one-byte retune
    /// flips the rim. The floor keeps every bundled core 0.04 of
    /// luma off the pivot. The drawn composite is not gated: it is
    /// near zero for any light core on a white ground in every
    /// palette, a property of the two-tone design.
    static let pivotFloor = 0.54

    @Test("Every bundled handle stays distinguishable from its hairline")
    @MainActor
    func bundledHandleClearsTheHairline() throws {
        for palette in PaletteCatalog.bundled() {
            let hex = try #require(palette.colors["kiwishelf.handle_color"])
            let core = try #require(ColorPalette.rgbHex(hex))
            let rim = try #require(
                ShelfHandleSpec.hairlineColor(hex: hex)
                    .usingColorSpace(.sRGB)
            )
            let tone = rim.redComponent > 0.5 ? "#FFFFFF" : "#000000"
            let distance = try #require(
                ColorVision.lumaDistance(core, over: tone)
            )
            #expect(
                distance >= Self.pivotFloor,
                "\(palette.name): \(distance)"
            )
        }
    }

    /// The starter paints the handle as Glass and the default
    /// palette do, so a first run wears both whole (#3377, #1739);
    /// Automatic is a colour of its own and wears no palette.
    @Test("A first run's handle is the default accent, Automatic is not")
    func starterWearsTheAccent() throws {
        let sizes = [CGSize(width: 1512, height: 982)]
        let starter = StarterSetup.standardLayout(sizes: sizes)
            .settings(sizes: sizes)
        let fresh = TilingSettings()
        #expect(fresh.kiwishelf.handleColor.isEmpty)
        #expect(
            starter.kiwishelf.handleColor
                == fresh.kiwishelf.activeItemColor
        )
        #expect(!PaletteCatalog.defaultPalette().isApplied(to: fresh))
        let gold = try #require(
            PaletteCatalog.authored().first {
                $0.name == "Kiwi Gold"
            }
        )
        var settings = fresh
        gold.apply(to: &settings)
        #expect(gold.isApplied(to: settings))
        settings.kiwishelf.handleColor = ""
        #expect(!gold.isApplied(to: settings))
    }

    @Test("Automatic is the label ink at each strength in either mode")
    @MainActor
    func automaticFollowsTheAppearance() throws {
        let aqua = try #require(NSAppearance(named: .aqua))
        let darkAqua = try #require(NSAppearance(named: .darkAqua))
        func resolved(
            _ hex: String,
            _ appearance: NSAppearance,
            _ ink: (String) -> NSColor
        ) -> NSColor {
            var color = NSColor.clear
            appearance.performAsCurrentDrawingAppearance {
                let cg = ink(hex).cgColor
                color = NSColor(cgColor: cg) ?? .clear
            }
            return color.usingColorSpace(.sRGB) ?? color
        }
        typealias Spec = ShelfHandleSpec
        let inks: [(CGFloat, (String) -> NSColor)] = [
            (Spec.restStrength, Spec.restColor(hex:)),
            (Spec.fillStrength, Spec.fillColor(hex:)),
        ]
        for (strength, ink) in inks {
            let light = resolved("", aqua, ink)
            let dark = resolved("", darkAqua, ink)
            #expect(abs(light.alphaComponent - strength) < 0.02)
            #expect(abs(dark.alphaComponent - strength) < 0.02)
            // Dark ink on light, light ink on dark.
            #expect(light.redComponent < 0.5)
            #expect(dark.redComponent > 0.5)
            // A picked colour: its own alpha times the strength.
            let set = resolved("#FF000080", darkAqua, ink)
            #expect(abs(set.redComponent - 1) < 0.01)
            #expect(set.greenComponent < 0.01)
            #expect(
                abs(set.alphaComponent - 128.0 / 255 * strength) < 0.01
            )
        }
        #expect(Spec.restStrength < Spec.fillStrength)
    }
}
