import KiwiDeskCore
import SwiftUI

/// Swatch preview tiles for Home card plates (#786).

/// Fan of five color circles previewing active palette
/// (`SettingsColorSurfaceTests`).
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

    /// Five primary palette colors centered on Space Bar active accent.
    private var hexes: [String] {
        [
            settings.borderStyle.focusedColor,
            settings.spaceBarStyle.focusedItemColor,
            settings.spaceBarStyle.activeItemColor,
            settings.appBarStyle.hoverFillColor,
            settings.appBarStyle.itemColor,
        ]
    }

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

/// 4x2 grid of representative swatches for Advanced Colors home card (#786).
struct HomeCardSwatchGridTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    // Near-square cells — owner eyeballed both cuts and ruled
    // the square back in over a 2:1 landscape stretch
    // (2026-08-09, on device).
    private static let cell = CGSize(width: 34, height: 26)

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
