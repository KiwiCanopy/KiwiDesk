import AppKit
import KiwiDeskCore
import SwiftUI

/// Each layout's picture for a Layout menu item: its schematic at
/// rest on a small screen of the cards' plate, in the plate's
/// palette, so its ghost windows read in a light or dark menu, the
/// schematic inset so every layout shows the same rim (#2777).
/// Memoized for the process: every input is fixed — default
/// settings, and plate tokens alike in light and dark — so a picture
/// keyed on the appearance or the draft needs a memo key first.
/// Rendered once per layout and kept.
@MainActor
enum LayoutMenuPictures {
    private static var memo: [LayoutMode: NSImage] = [:]

    /// How many windows a picture draws: the schematic's default,
    /// and Floating's whole scatter.
    static func windows(for mode: LayoutMode) -> Int {
        let count = LayoutSchematic.windowCount(
            LayoutSchematic.defaultWindowCount,
            for: mode
        )
        return mode == .floating ? max(count, 3) : count
    }

    /// The picture's size in points, and the plate's rim around
    /// the schematic.
    static let size = CGSize(width: 40, height: 25)
    static let rim: CGFloat = 3

    /// The schematic's own canvas, and the scale that fits it inside
    /// the plate with `rim` showing on every side.
    private static let tile = CGSize(
        width: SchematicScale.tile.width ?? 132,
        height: SchematicScale.tile.height
    )
    private static var fit: CGFloat {
        min(
            (size.width - 2 * rim) / tile.width,
            (size.height - 2 * rim) / tile.height
        )
    }

    static func image(_ mode: LayoutMode) -> NSImage {
        if let hit = memo[mode] { return hit }
        let settings = TilingSettings()
        let renderer = ImageRenderer(
            content: LayoutSchematicView(
                mode: mode,
                settings: settings,
                windows: windows(for: mode),
                scale: .tile
            )
            .scaleEffect(fit)
            .frame(
                width: tile.width * fit,
                height: tile.height * fit
            )
            .frame(width: size.width, height: size.height)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(SettingsTheme.previewPlate)
            )
            .environment(
                \.schematicPalette,
                HomeCardPlate.palette(settings)
            )
        )
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: size)
        image.size = size
        memo[mode] = image
        return image
    }
}
