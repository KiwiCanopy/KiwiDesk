import SwiftUI

/// The dashed tile that ends a line of look or palette tiles: a
/// symbol over a label, one action — Save current colors as…, Save
/// current look as… (#1684) and Simple's More looks… (#1740). The
/// label sits inside the plate, where it can wrap, since the name
/// line truncates; that line renders blank, and the caption room
/// matches its neighbours', so the tile keeps the line's height.
struct DashedActionTile: View {
    let systemImage: String
    let label: String
    /// The caption lines the line's other tiles reserve.
    var captionLines = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PaletteTile(
                name: " ",
                dashed: true,
                captionLines: captionLines
            ) {
                RoundedRectangle(
                    cornerRadius: PaletteSceneThumbnail.plateRadius
                )
                .fill(SettingsTheme.sunken)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: systemImage).font(.title2)
                        Text(label)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(4)
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
