import AppKit
import Testing

@testable import KiwiDeskCore

/// The sheen's contrast (#1644), measured on the repo instrument
/// (`ColorVision`), never eyeballed. A bright top loses contrast
/// on near-white and a dark bottom on near-black, so the ramp is
/// capped at the #578 bar: a colour clearing 3:1 on a wallpaper
/// extreme flat clears it at every stop of its ramp. A colour
/// already under the bar there has none to lose to the sheen.
@Suite("Border sheen contrast (#1644)")
struct BorderSheenContrastTests {
    private static let grounds = ["#FFFFFF", "#000000"]
    private static let floor = Double(BorderSheen.contrastFloor)

    /// Every stroke the sheen paints, per bundled palette and the
    /// shipped defaults.
    private static var strokes: [(name: String, hex: String)] {
        let keys = [
            "border.focused_color", "kiwishelf.highlight_color",
            "kiwishelf.border_color", "drag.ghost.border_color",
            "drag.drop_zone.border_color",
        ]
        var out: [(String, String)] = [
            ("default ring", BorderStyle().focusedColor),
            ("default highlight", KiwiShelf().highlightColor),
        ]
        for palette in PaletteCatalog.bundled() {
            for key in keys {
                if let hex = palette.colors[key], !hex.isEmpty {
                    out.append(("\(palette.name) \(key)", hex))
                }
            }
        }
        return out
    }

    private static func hex(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        return String(
            format: "#%02X%02X%02X",
            Int((c.redComponent * 255).rounded()),
            Int((c.greenComponent * 255).rounded()),
            Int((c.blueComponent * 255).rounded())
        )
    }

    /// The stroke's RGB, alpha dropped: the #578 bar reads the
    /// colour, which the ramp keeps the alpha of.
    private static func opaque(_ hex: String) -> String {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : hex[...]
        return "#" + digits.prefix(6)
    }

    @Test("A stroke clearing the #578 bar keeps it at every stop")
    func rampKeepsTheBar() throws {
        #expect(!PaletteCatalog.authored().isEmpty)
        var bound = 0
        for (name, hex) in Self.strokes {
            let ramp = BorderSheen.colors(hex: hex).map(Self.hex)
            for ground in Self.grounds {
                let flat = try #require(
                    ColorVision.contrast(Self.opaque(hex), ground)
                )
                guard flat >= Self.floor else { continue }
                bound += 1
                for stop in ramp {
                    let contrast = try #require(
                        ColorVision.contrast(stop, ground)
                    )
                    #expect(
                        contrast >= Self.floor,
                        Comment(
                            rawValue:
                                "\(name) \(stop) on \(ground): "
                                + "\(contrast) (flat \(flat))"
                        )
                    )
                }
            }
        }
        // The default ring clears the bar at both ends (#578), so
        // the cap is exercised, not vacuous.
        #expect(bound >= 2)
    }

    /// The cap binds where it must: uncapped, the owner-eyeballed
    /// lift takes the default ring under the bar on white, and the
    /// capped top sits above that uncapped reading.
    @Test("The default ring's top is capped, not lifted in full")
    func defaultRingIsCapped() throws {
        let hex = BorderStyle().focusedColor
        let rgba = try #require(DragVisual.parseHex(hex))
        let (h, s, l) = BorderStyle.rgbToHSL(
            r: rgba.red,
            g: rgba.green,
            b: rgba.blue
        )
        let full = BorderStyle.hslToRGB(
            h: h,
            s: s,
            l: l + (1 - l) * BorderSheen.lift
        )
        let uncapped = Self.hex(
            NSColor(srgbRed: full.0, green: full.1, blue: full.2, alpha: 1)
        )
        let uncappedOnWhite = try #require(
            ColorVision.contrast(uncapped, "#FFFFFF")
        )
        let top = Self.hex(BorderSheen.colors(hex: hex)[0])
        let onWhite = try #require(ColorVision.contrast(top, "#FFFFFF"))
        #expect(uncappedOnWhite < Self.floor)
        #expect(onWhite > uncappedOnWhite)
        #expect(onWhite >= Self.floor)
    }

    /// The bar highlight and the shelf border against the bundled
    /// palettes' own plates
    /// (`IdleItemContrastTests`' instrument), capped over the
    /// grounds the live bar hands it: the sheen may not take a
    /// highlight that reads against its plate under the bar at any
    /// stop. Uncapped, Clean Light, Monochrome and Ultraviolet fell
    /// under it (2.78, 2.87 and 2.64:1).
    @Test(
        "The highlight and the border keep the bar against their plates",
        arguments: ["kiwishelf.highlight_color", "kiwishelf.border_color"]
    )
    func strokesOnPlates(_ key: String) throws {
        var measured = 0
        for palette in PaletteCatalog.bundled() {
            guard let highlight = palette.colors[key],
                let fill = palette.colors["kiwishelf.fill_color"]
            else { continue }
            let ramp = BorderSheen.colors(
                hex: highlight,
                over: BorderSheen.grounds(plate: fill)
            ).map(Self.hex)
            for wallpaper in Self.grounds {
                let plate = try #require(
                    ColorVision.composite(fill, over: wallpaper)
                )
                let flat = try #require(
                    ColorVision.contrast(Self.opaque(highlight), plate)
                )
                guard flat >= Self.floor else { continue }
                for stop in ramp {
                    let contrast = try #require(
                        ColorVision.contrast(stop, plate)
                    )
                    #expect(
                        contrast >= Self.floor,
                        Comment(
                            rawValue:
                                "\(palette.name) \(stop) on \(plate): "
                                + "\(contrast) (flat \(flat))"
                        )
                    )
                }
                measured += 1
            }
        }
        #expect(measured > 0)
    }
}
