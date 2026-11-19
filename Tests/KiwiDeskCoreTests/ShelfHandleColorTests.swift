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
                let accent = palette.colors[source] ?? ""
                let shade = ColorPaletteKeys.handleShades[accent.uppercased()]
                #expect(paint == (shade ?? accent), name)
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
        // The default accent's duty shade (#3514).
        let accent = fresh.kiwishelf.activeItemColor
        #expect(
            starter.kiwishelf.handleColor
                == ColorPaletteKeys.handleShades[accent.uppercased()]
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

    @Test("The fill is the ink; the rest is it mixed toward its tone")
    @MainActor
    func restMixesTowardTheTone() throws {
        let aqua = try #require(NSAppearance(named: .aqua))
        let darkAqua = try #require(NSAppearance(named: .darkAqua))
        typealias Spec = ShelfHandleSpec
        func resolved(
            _ color: NSColor,
            _ appearance: NSAppearance
        ) -> NSColor {
            var out = NSColor.clear
            appearance.performAsCurrentDrawingAppearance {
                out = NSColor(cgColor: color.cgColor) ?? .clear
            }
            return out.usingColorSpace(.sRGB) ?? out
        }
        // An independent statement of the rule (#3514): each channel
        // `restMix` of the way to black beside a light ink, to white
        // beside a dark one, the alpha kept.
        func expectedRest(_ ink: NSColor) -> NSColor {
            let luma =
                0.2126 * ink.redComponent + 0.7152 * ink.greenComponent
                + 0.0722 * ink.blueComponent
            let tone: CGFloat = luma > 0.5 ? 0 : 1
            let mix = { (c: CGFloat) in c + (tone - c) * Spec.restMix }
            return NSColor(
                srgbRed: mix(ink.redComponent),
                green: mix(ink.greenComponent),
                blue: mix(ink.blueComponent),
                alpha: ink.alphaComponent
            )
        }
        for appearance in [aqua, darkAqua] {
            for hex in ["", "#FF000080", "#8DB354"] {
                let fill = resolved(Spec.fillColor(hex: hex), appearance)
                let rest = resolved(Spec.restColor(hex: hex), appearance)
                let name = Comment(rawValue: "\(appearance.name) \(hex)")
                // The fill is the ink at its own alpha, never forced
                // opaque: Automatic keeps the label ink's own.
                if hex.isEmpty {
                    #expect(fill.alphaComponent < 1, name)
                } else {
                    let own = try #require(
                        NSColor(kiwiHex: hex).usingColorSpace(.sRGB)
                    )
                    #expect(
                        abs(fill.alphaComponent - own.alphaComponent)
                            < 0.01,
                        name
                    )
                    #expect(abs(fill.redComponent - own.redComponent) < 0.01)
                }
                let want = expectedRest(fill)
                #expect(
                    abs(rest.redComponent - want.redComponent) < 0.01,
                    name
                )
                #expect(
                    abs(rest.greenComponent - want.greenComponent) < 0.01,
                    name
                )
                #expect(abs(rest.blueComponent - want.blueComponent) < 0.01)
                #expect(
                    abs(rest.alphaComponent - fill.alphaComponent) < 0.01,
                    name
                )
            }
        }
        // The step is real: a light ink rests darker, a dark one
        // lighter.
        let lightInk = resolved(Spec.restColor(hex: ""), darkAqua)
        #expect(lightInk.redComponent < 0.7)
        let darkInk = resolved(Spec.restColor(hex: ""), aqua)
        #expect(darkInk.redComponent > 0.3)
    }
}
