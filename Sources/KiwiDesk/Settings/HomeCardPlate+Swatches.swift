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
            settings.kiwishelf.activeItemColor,
            settings.kiwishelf.hoverFillColor,
            settings.kiwishelf.itemColor,
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
                    (palette ?? .unresolved).ink
                        .opacity(0.2)
                )
            )
            .frame(width: size, height: size)
    }
}
