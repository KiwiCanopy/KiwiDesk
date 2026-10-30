import AppKit
import KiwiDeskCore
import SwiftUI

/// `kiwidesk preview <look.json> <out.png>`: a look file's gallery
/// preview (#1740 ▸ Preview) — the shelf card's `LookPlate` at its
/// own size with its pocket mark standing, painted over default
/// settings on a fixed four-Space desk in dark mode, scaled to a
/// fixed pixel size. Reads the file
/// like Import… does; needs no running app. The verb, `usage` and
/// `pixels` are the KiwiDesk-Looks CI's contract
/// (`CLIPreviewContractTests`).
enum CLIPreview {
    static let verb = "preview"

    static let usage = "usage: kiwidesk preview <look.json> <out.png>"

    /// The PNG's size, the site card's 16:10 at its 720 px slot.
    static let pixels = CGSize(width: 768, height: 480)

    /// The card's plate, 16:10 at its own height.
    @MainActor static let points = CGSize(
        width: PaletteSceneThumbnail.baseHeight * 1.6,
        height: PaletteSceneThumbnail.baseHeight
    )

    static func run(_ arguments: [String]) -> Int32 {
        guard arguments.count == 4 else { return fail(usage) }
        let input = URL(fileURLWithPath: arguments[2])
        let output = URL(fileURLWithPath: arguments[3])
        let data: Data
        do {
            data = try Data(contentsOf: input)
        } catch {
            return fail("error: \(input.path): \(error)")
        }
        let look: ShelfLook
        do {
            look = try LookStore.importLook(data: data)
        } catch {
            return fail("error: \(input.path) is not a look file: \(error)")
        }
        // main.swift calls `runCLI` on the main thread.
        guard let png = MainActor.assumeIsolated({ render(look) }) else {
            return fail("error: the preview could not be drawn")
        }
        do {
            try png.write(to: output, options: .atomic)
        } catch {
            return fail("error: \(output.path): \(error)")
        }
        return 0
    }

    /// The PNG bytes of `look`'s plate on the fixed desk.
    @MainActor static func render(_ look: ShelfLook) -> Data? {
        let config = desk(look)
        let plate = LookPlate(
            settings: config.settings,
            spaceLabels: BarsPanelPreview.spaceLabels(of: config),
            drawsPocket: true
        )
        .frame(width: points.width)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: plate)
        renderer.scale = pixels.height / points.height
        var image: CGImage?
        // The theme's tokens resolve through the drawing appearance,
        // which a headless process takes from the host.
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            image = renderer.cgImage
        }
        guard let image else { return nil }
        return NSBitmapImageRep(cgImage: image)
            .representation(using: .png, properties: [:])
    }

    /// Spaces 1–4 in BSP, wearing `look` over default settings with
    /// the pocket on the Space Bar's edge, where the starter and
    /// every bundled look put it; a look carrying its own edge wins.
    static func desk(_ look: ShelfLook) -> GuiConfig {
        var config = GuiConfig()
        var base = TilingSettings()
        base.kiwishelf.pocketEdge = base.spaceBarStyle.edge
        config.settings = look.painted(over: base)
        config.spaces = (1...4).map { SpaceID($0) }
        return config
    }

    private static func fail(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        return 1
    }
}
