import AppKit
import KiwiDeskCore
import SwiftUI

/// `kiwidesk preview <look.json> <out.png>`: a look file's gallery
/// preview (#1740 ▸ Preview) — the shelf card's `LookPlate`, painted
/// over default settings on a fixed four-Space desk in dark mode,
/// at a fixed size and scale so every machine writes the same
/// pixels. Reads the file like Import… does; needs no running app.
enum CLIPreview {
    static let verb = "preview"

    static let usage = "usage: kiwidesk preview <look.json> <out.png>"

    /// The plate in points, the site card's 16:10; the PNG is
    /// `scale` times as large, 768 × 480, to fill the card's 720 px.
    static let size = CGSize(width: 192, height: 120)
    static let scale: CGFloat = 4

    static func run(_ arguments: [String]) -> Int32 {
        guard arguments.count == 4 else {
            return fail(usage)
        }
        let input = URL(fileURLWithPath: arguments[2])
        let output = URL(fileURLWithPath: arguments[3])
        let look: ShelfLook
        do {
            look = try LookStore.importLook(
                data: Data(contentsOf: input)
            )
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
        let settings = look.painted(over: TilingSettings())
        let plate = LookPlate(
            settings: settings,
            spaceLabels: spaceLabels(settings),
            height: size.height
        )
        .frame(width: size.width)
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: plate)
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: image)
            .representation(using: .png, properties: [:])
    }

    /// Spaces 1–4 in tiling mode, labelled as the look labels them.
    @MainActor static func spaceLabels(
        _ settings: TilingSettings
    ) -> [SpaceGlyph] {
        (1...4).map { id in
            KiwiCore.spaceBarLabel(
                identifier: KiwiCore.spaceIdentifier(
                    id: SpaceID(id),
                    icon: nil
                ),
                mode: .bsp,
                label: settings.spaceBarStyle.itemLabel
            )
        }
    }

    private static func fail(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        return 1
    }
}
