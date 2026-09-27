import KiwiDeskCore
import SwiftUI

/// Palette tile container (#757).
struct PaletteTile<Plate: View>: View {
    let name: String
    var caption: String?
    var isApplied = false
    var dashed = false
    @ViewBuilder var plate: () -> Plate

    /// The plate's height matching `PaletteSceneThumbnail.baseHeight`.
    static var plateHeight: CGFloat {
        PaletteSceneThumbnail.baseHeight
    }

    /// Derived inset maintaining concentric corner radii.
    private static var inset: CGFloat {
        SettingsTheme.disclosureRadius
            - PaletteSceneThumbnail.plateRadius
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            plate()
                .frame(height: Self.plateHeight)
            nameLine
            Text(caption ?? " ")
                .font(.caption2)
                .foregroundStyle(SettingsTheme.ink3)
                .lineLimit(1)
        }
        .padding(Self.inset)
        .frame(maxWidth: .infinity)
        .overlay(frame)
    }

    /// Leading checkmark indicator for active palette
    /// (`ColorField`, `FitGapsAction`, `LoginItemCard`).
    private var nameLine: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SettingsTheme.ink)
                .opacity(isApplied ? 1 : 0)
                .accessibilityLabel(
                    L("palettes.applied", "Applied")
                )
                .accessibilityHidden(!isApplied)
                .frame(width: 10)
            Text(name)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var frame: some View {
        RoundedRectangle(
            cornerRadius: SettingsTheme.disclosureRadius
        )
        .strokeBorder(
            isApplied
                ? AnyShapeStyle(SettingsTheme.accent)
                : AnyShapeStyle(SettingsTheme.hairline),
            style: StrokeStyle(
                lineWidth: isApplied
                    ? SettingsTheme.paletteCardStrokeApplied
                    : SettingsTheme.paletteCardStroke,
                dash: dashed ? [4] : []
            )
        )
    }
}
