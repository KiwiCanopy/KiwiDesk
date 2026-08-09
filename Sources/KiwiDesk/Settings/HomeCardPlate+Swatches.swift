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
                    (palette?.ink ?? Color.white).opacity(0.2)
                )
            )
            .frame(width: size, height: size)
    }
}

/// The Advanced Colours answer as a picture: a grid of the
/// colour surface's real values, through the same
/// `ColorPaletteKeys` order the palette bridge reads, capped by
/// the same census-derived count the subtitle states
/// (`HomeCardContent.advancedColourCount`) so the grid and its
/// caption cannot answer from two sources.
struct HomeCardSwatchGridTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    private static let columns = 4
    private static let rows = 2

    var body: some View {
        // One extract per render of this one tile — the surface
        // read the bridge reads, not per-card work
        // (`PaletteShelf.liveColors` lesson: never per row).
        let values = ColorPaletteKeys.extract(from: settings)
        let shown = ColorPaletteKeys.all
            .compactMap { values[$0] }
            .prefix(
                min(
                    Self.columns * Self.rows,
                    HomeCardContent.advancedColourCount
                )
            )
        VStack(spacing: 5) {
            ForEach(0..<Self.rows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(
                        0..<Self.columns,
                        id: \.self
                    ) { column in
                        cell(
                            Array(shown),
                            index: row * Self.columns + column
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(
        _ shown: [String],
        index: Int
    ) -> some View {
        if index < shown.count {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(kiwiHex: shown[index]))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            (palette?.ink ?? Color.white)
                                .opacity(0.2)
                        )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }
}
