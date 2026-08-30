import KiwiDeskCore
import SwiftUI

/// Desktop preview scene for the Bars panel (#678, `HomeCardBarsTile`).
struct BarsPanelPreview: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeCardBarsTile(
                settings: model.config.settings,
                spaceCount: model.config.spaces.count,
                scale: 1.8,
                spaceLabels: spaceLabels
            )
            .padding(12)
            .frame(height: 210)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SettingsTheme.previewPlate)
            )
            // 16b dark seam — see `SettingsTheme.planeRing`.
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        SettingsTheme.planeRing,
                        lineWidth: 1
                    )
            )
            .environment(
                \.schematicPalette,
                HomeCardPlate.palette(model.config.settings)
            )
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            Text(
                L(
                    "panel.caption.draft",
                    "Shows your draft, not the saved profile."
                )
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
        }
    }

    /// Each declared space's identifier, the real bar's rule:
    /// the stored icon, else the space's ordinal.
    private var spaceLabels: [String] {
        let icons = model.config.settings.spaceIcons
        return model.config.spaces.enumerated().map {
            index,
            space in
            icons[space] ?? String(index + 1)
        }
    }
}
