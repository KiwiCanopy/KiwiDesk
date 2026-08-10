import KiwiDeskCore
import SwiftUI

/// The Bars panel content (#678 redesign spec, turn 7a): ONE desktop
/// scene with both bars in place — the fused view the owner
/// asked for (2026-08-10), so "both on top" coexistence is
/// seen, not described. The scene is `HomeCardBarsTile`, the
/// Home plate's own renderer, mounted larger with the same
/// palette fold — one renderer, two sizes, never a second
/// drawing. Space pips are the draft's real space count.
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
