import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Colours & Animations picture draws the sheen as the live
/// surfaces do (#1644): Core's ramp on the focused ring, the bar
/// highlight and border and the drag borders, from the draft's
/// `border.sheen`, at `.panel` only (gui.md ▸ #753).
@MainActor
@Suite("Palette scene sheen (#1644)")
struct PaletteSceneSheenTests {
    /// A ring colour nothing else in the scene uses, under the
    /// #578 bar on white so its lift is not capped.
    private static let ring = "#FF80FF"

    /// The ramp's top stop for the ring — what only a sheened
    /// ring draws.
    private static var lifted: (UInt8, UInt8, UInt8) {
        let top = BorderSheen.colors(hex: ring)[0]
            .usingColorSpace(.sRGB)!
        return (
            UInt8((top.redComponent * 255).rounded()),
            UInt8((top.greenComponent * 255).rounded()),
            UInt8((top.blueComponent * 255).rounded())
        )
    }

    private static func scene(
        _ scale: PaletteSceneScale,
        sheen: Bool
    ) -> PaletteSceneThumbnail {
        var colors = PaletteCatalog.defaultPalette().colors
        colors["border.focused_color"] = ring
        return PaletteSceneThumbnail(
            palette: ColorPalette(name: "", colors: colors),
            scene: scale,
            drawsBorder: true,
            drawsSheen: sheen
        )
    }

    @Test("the sheen draws at panel scale only, from the switch")
    func sheensAtPanelOnly() {
        #expect(Self.scene(.panel, sheen: true).sheens)
        #expect(!Self.scene(.panel, sheen: false).sheens)
        #expect(!Self.scene(.tile, sheen: true).sheens)
    }

    /// Rendered and read back: the ring's lifted top colour shows
    /// only with the sheen on — the scene DRAWS it, not only
    /// decides it.
    @Test("the panel paints the ring's lifted top")
    func panelDrawsTheRamp() throws {
        let on = try Self.liftedPixels(sheen: true)
        let off = try Self.liftedPixels(sheen: false)
        #expect(on > 20, "lifted pixels with the sheen on: \(on)")
        #expect(off == 0, "lifted pixels with the sheen off: \(off)")
    }

    private static func liftedPixels(sheen: Bool) throws -> Int {
        let renderer = ImageRenderer(
            content: scene(.panel, sheen: sheen).frame(width: 320)
        )
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let (w, h) = (image.width, image.height)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: w,
                    height: h,
                    bitsPerComponent: 8,
                    bytesPerRow: w * 4,
                    space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast
                        .rawValue
                )
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        try #require(drawn)
        let target = lifted
        let near = { (a: UInt8, b: UInt8) in abs(Int(a) - Int(b)) <= 3 }
        var count = 0
        for pixel in stride(from: 0, to: bytes.count, by: 4)
        where bytes[pixel + 3] > 250
            && near(bytes[pixel], target.0)
            && near(bytes[pixel + 1], target.1)
            && near(bytes[pixel + 2], target.2)
        {
            count += 1
        }
        return count
    }

    /// Every scene hands the draft's sheen in — the argument has
    /// no default, and this holds WHICH value each site reads.
    @Test(
        "every palette scene reads the draft's sheen",
        arguments: [
            "AdvancedColorsPanel.swift",
            "PaletteScenePanel.swift",
            "PaletteShelf.swift",
        ]
    )
    func scenesReadTheSheen(file: String) throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors"
            )
            .appendingPathComponent(file)
        let source = try SourceScan.strippedSource(at: url)
        let needle = "drawsSheen: model.config.settings.borderStyle.sheen"
        #expect(source.components(separatedBy: needle).count - 1 == 1)
    }
}
