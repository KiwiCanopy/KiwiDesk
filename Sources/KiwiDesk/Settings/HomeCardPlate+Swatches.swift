import KiwiDeskCore
import SwiftUI

/// The swatch tiles of the Home card plates (#786): Colours &
/// Motion and Advanced Colours. Split from
/// `HomeCardPlate.swift` at the file-size target.

/// Five circles of the palette's own voices, the primary accent
/// largest in the middle — a fan of what the user's colours ARE,
/// not an editor. Read-only fills; the editing surface stays in
/// Advanced Colours (`SettingsColorSurfaceTests`).
struct HomeCardColorsTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    /// Fan diameters, centre-out symmetric.
    private static let sizes: [CGFloat] = [14, 20, 30, 20, 14]

    var body: some View {
        HStack(spacing: 9) {
            ForEach(
                Array(hexes.enumerated()),
                id: \.offset
            ) { index, hex in
                circle(hex, size: Self.sizes[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The five voices, ordered so the Space Bar's active
    /// accent — the palette's primary — lands on the biggest
    /// circle.
    private var hexes: [String] {
        [
            settings.borderStyle.focusedColor,
            settings.spaceBarStyle.focusedItemColor,
            settings.spaceBarStyle.activeItemColor,
            settings.appBarStyle.hoverFillColor,
            settings.appBarStyle.itemColor,
        ]
    }

    /// Every circle takes the light-ink edge, not only the dark
    /// ones: a swatch near the plate's own colour would
    /// otherwise vanish, and which swatch that is depends on
    /// the user's palette.
    private func circle(
        _ hex: String,
        size: CGFloat
    ) -> some View {
        Circle()
            .fill(Color(kiwiHex: hex))
            .overlay(
                Circle().strokeBorder(
                    (palette?.ink ?? SettingsTheme.plateInk)
                        .opacity(0.2)
                )
            )
            .frame(width: size, height: size)
    }
}

/// The Advanced Colours answer as a picture: the prototype's
/// 4×2 grid, drawn from the REAL paths whose shipped defaults
/// are the prototype's own hexes (owner, 2026-08-09 — the
/// curated eight over the surface's first eight, which were
/// all App Bar values and half duplicates; the full ~24 would
/// be too many). Fixed square-ish cells, centred — infinity
/// cells stretched to bars at the grid's wide step.
struct HomeCardSwatchGridTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    // Landscape ~2:1 cells (owner, 2026-08-09): swatches read
    // longer than tall, spread with breathing room to every
    // side rather than squares crowding the centre.
    private static let cell = CGSize(width: 46, height: 23)

    var body: some View {
        let hexes = self.hexes
        VStack(spacing: 5) {
            row(Array(hexes[0..<4]))
            row(Array(hexes[4..<8]))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Eight voices across the families the area edits — bars,
    /// borders, badges — one value each, no duplicates under
    /// the defaults.
    private var hexes: [String] {
        [
            settings.spaceBarStyle.activeItemColor,
            settings.appBarStyle.hoverFillColor,
            settings.spaceBarStyle.focusedItemColor,
            settings.appBarStyle.itemColor,
            settings.spaceBarStyle.fillColor,
            settings.borderStyle.focusedColor,
            settings.spaceBarStyle.groupBadgeColor,
            settings.spaceBarStyle.itemColor,
        ]
    }

    private func row(_ hexes: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(
                Array(hexes.enumerated()),
                id: \.offset
            ) { _, hex in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(kiwiHex: hex))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                (palette?.ink
                                    ?? SettingsTheme
                                    .plateInk)
                                    .opacity(0.2)
                            )
                    )
                    .frame(
                        width: Self.cell.width,
                        height: Self.cell.height
                    )
            }
        }
    }
}
