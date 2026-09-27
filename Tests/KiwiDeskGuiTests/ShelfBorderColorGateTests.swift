import CoreGraphics
import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The shelf border's colour row on Advanced Colours (#1679):
/// greyed while the border is off, with its reason as a live link
/// to Bars beneath the grid — the #1310 shape — only while a bar
/// shows, since with none the card's header carries the reason.
@Suite("Shelf border colour gate")
@MainActor
struct ShelfBorderColorGateTests {
    private static func settings(
        border: Bool,
        barShows: Bool = true
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf.border = border
        settings.spaceBarStyle.enabled = barShows
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = false
        return settings
    }

    @Test("The row greys, and links, only while the border is off")
    func gateFollowsTheSwitch() {
        let off = AdvancedColorsGates(settings: Self.settings(border: false))
        #expect(off.shelfBorderOff)
        #expect(off.shelfBorderNeedsReference)
        let on = AdvancedColorsGates(settings: Self.settings(border: true))
        #expect(!on.shelfBorderOff)
        #expect(!on.shelfBorderNeedsReference)
    }

    @Test("With no bar shown the header's reason stands instead")
    func headerOutranksTheLink() {
        let gates = AdvancedColorsGates(
            settings: Self.settings(border: false, barShows: false)
        )
        #expect(gates.shelfBorderOff)
        #expect(!gates.shelfBorderNeedsReference)
    }

    /// One branch, one value (`CrossReferenceRowSlotTests`).
    @Test("The border row's prose places its link")
    func prosePlacesItsLink() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            AdvancedColorsHelp.shelfBorderReference.contains(
                CrossReferenceRow.linkSlot
            )
        )
    }

    /// The render sites wire those two values: the colour row
    /// greys on `shelfBorderOff`, and the link renders under
    /// `shelfBorderNeedsReference` alone. Whitespace is squashed
    /// so a re-wrap cannot red it.
    @Test(
        "The row greys and the link renders on the gate's values",
        arguments: [
            (
                "AdvancedColorRow+Bars.swift",
                "gated(gates.shelfBorderOff,"
                    + "AdvancedColorsHelp.shelfBorderOff)"
            ),
            (
                "BarColorCards.swift",
                "ifgates.shelfBorderNeedsReference{CrossReferenceRow("
                    + "prose:AdvancedColorsHelp.shelfBorderReference,"
            ),
        ]
    )
    func renderSitesTakeTheGate(file: String, needle: String) throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors"
            )
            .appendingPathComponent(file)
        let source = try SourceScan.strippedSource(at: url)
            .filter { !$0.isWhitespace }
        let pieces = source.components(separatedBy: needle)
        #expect(pieces.count - 1 == 1, "\(file)")
    }

    /// The census gate names the switch, so a search hit and the
    /// diff narrate the row as the border's.
    @Test("The census gates the colour and the width on the switch")
    func censusGates() {
        let gated = SettingKey.kiwishelf(.border)
        #expect(
            KiwiShelfKey.borderColor.placement.gate?.settings
                .contains(gated) == true
        )
        #expect(
            KiwiShelfKey.borderWidth.placement.gate?.settings
                == [gated]
        )
    }
}

/// The Bars preview draws the draft's border (#1679): both bars'
/// specs carry its width at the frame's scale — nothing while the
/// switch is off — and its colour.
@Suite("Shelf border in the Bars preview")
@MainActor
struct ShelfBorderPreviewTests {
    private static let scale: CGFloat = 1.8

    private static func tile(border: Bool) -> HomeCardBarsTile {
        var settings = TilingSettings()
        settings.kiwishelf.border = border
        settings.kiwishelf.borderWidth = 3
        settings.kiwishelf.borderColor = "#1C1C1E"
        return HomeCardBarsTile(settings: settings, scale: scale)
    }

    private static func specs(
        _ tile: HomeCardBarsTile
    ) -> [HomeCardBarsTile.BarSpec] {
        [
            tile.spaceSpec(tile.settings.spaceBarLook),
            tile.appSpec(
                tile.settings.appBarLook(
                    for: tile.settings.appBarHosts[0]
                ),
                vertical: false
            ),
        ]
    }

    @Test("Both bars' specs carry the draft's border")
    func specsFollowTheDraft() {
        let unit = HomeCardBarsTile.indicatorPerPoint * Self.scale
        for spec in Self.specs(Self.tile(border: true)) {
            #expect(spec.borderWidth == 3 * unit)
            #expect(spec.borderColor == "#1C1C1E")
        }
    }

    @Test("A border switched off draws no stroke")
    func offDrawsNothing() {
        for spec in Self.specs(Self.tile(border: false)) {
            #expect(spec.borderWidth == 0)
        }
    }

    /// The edge the strips draw strokes the spec's border, and
    /// the hairline only while there is none.
    @Test("The plate edge strokes the spec's border")
    func edgeStrokesTheBorder() throws {
        let on = try #require(Self.specs(Self.tile(border: true)).first)
        let edge = try #require(PreviewPlateEdge(spec: on, corner: 4).border)
        #expect(edge.hex == on.borderColor)
        #expect(edge.width == on.borderWidth)
        let off = try #require(Self.specs(Self.tile(border: false)).first)
        #expect(PreviewPlateEdge(spec: off, corner: 4).border == nil)
    }

    /// The strips draw that edge on every plate and box they
    /// paint: the bar strip's plate and box, the shelf strip's one
    /// plate. A site that goes back to a bare hairline reds here.
    @Test(
        "Every preview plate and box takes the edge",
        arguments: [
            ("HomeCardPlate+BarStrip.swift", 2),
            ("HomeCardPlate+ShelfStrip.swift", 1),
        ]
    )
    func stripsTakeTheEdge(file: String, sites: Int) throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(file)
        let source = try SourceScan.strippedSource(at: url)
        let pieces = source.components(separatedBy: "PreviewPlateEdge(")
        let count = pieces.count - 1
        #expect(count == sites, "\(file): \(count)")
    }

    /// The palette scene rims its bar plates in the palette's
    /// border colour only while the draft's switch is on.
    @Test("The palette scene's rim follows the switch")
    func sceneRimFollowsTheSwitch() throws {
        let palette = try #require(
            PaletteCatalog.bundled().first {
                $0.colors["kiwishelf.border_color"] != nil
            }
        )
        let on = PaletteSceneThumbnail(
            palette: palette,
            scene: .panel,
            drawsBorder: true,
            drawsSheen: false
        )
        #expect(on.borderRim == on.color("kiwishelf.border_color"))
        let off = PaletteSceneThumbnail(
            palette: palette,
            scene: .panel,
            drawsBorder: false,
            drawsSheen: false
        )
        #expect(off.borderRim == nil)
    }

    /// The rim is DRAWN, not only decided. The palette's border
    /// is a magenta nothing else in the scene uses. Rendered at
    /// 1x and read back as sRGB, the scene has a band of magenta
    /// pixels where the plates are rimmed while the switch is on,
    /// and none while it is off. Counting the rim's own colour,
    /// not "any difference", keeps renderer noise out of it.
    @Test("The palette panel draws its rim only with the switch on")
    func sceneDrawsTheRim() throws {
        let on = try Self.rimPixels(drawsBorder: true)
        let off = try Self.rimPixels(drawsBorder: false)
        // Two plates, each rimmed about 2 px wide round a
        // 300-odd-pt strip: well over a thousand pixels.
        #expect(on > 500, "rim pixels with the switch on: \(on)")
        #expect(off == 0, "rim pixels with the switch off: \(off)")
    }

    private static let rimHex = "#FF00FF"

    /// How many pixels of the rendered panel scene read as the
    /// rim's magenta.
    private static func rimPixels(drawsBorder: Bool) throws -> Int {
        var colors = PaletteCatalog.defaultPalette().colors
        colors["kiwishelf.border_color"] = rimHex
        let renderer = ImageRenderer(
            content: PaletteSceneThumbnail(
                palette: ColorPalette(name: "", colors: colors),
                scene: .panel,
                drawsBorder: drawsBorder,
                drawsSheen: false
            )
            .frame(width: 320)
        )
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast
                        .rawValue
                )
            else { return false }
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
            return true
        }
        try #require(drawn)
        var count = 0
        for pixel in stride(from: 0, to: bytes.count, by: 4)
        where bytes[pixel] > 200 && bytes[pixel + 1] < 60
            && bytes[pixel + 2] > 200 && bytes[pixel + 3] > 200
        {
            count += 1
        }
        return count
    }

    /// Every scene hands the draft's switch in — the argument has
    /// no default, and this holds WHICH value each site reads.
    @Test(
        "Every palette scene reads the draft's border switch",
        arguments: [
            "AdvancedColorsPanel.swift",
            "PaletteScenePanel.swift",
            "PaletteShelf.swift",
        ]
    )
    func scenesReadTheSwitch(file: String) throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors"
            )
            .appendingPathComponent(file)
        let source = try SourceScan.strippedSource(at: url)
        let needle = "drawsBorder: model.config.settings.kiwishelf.border"
        let pieces = source.components(separatedBy: needle)
        #expect(pieces.count - 1 == 1, "\(file)")
    }
}
