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

    private var spaceLabels: [HomeCardBarsTile.SpaceLabel] {
        Self.spaceLabels(
            spaces: model.config.spaces,
            icons: model.config.settings.spaceIcons
        )
    }

    /// Space label identifiers: the configured icon as Core
    /// classifies it — a symbol name draws as the symbol, an
    /// emoji or any other text as itself — else the ordinal.
    static func spaceLabels(
        spaces: [SpaceID],
        icons: [SpaceID: String]
    ) -> [HomeCardBarsTile.SpaceLabel] {
        spaces.enumerated().map { index, space in
            guard let icon = icons[space] else {
                return .text(String(index + 1))
            }
            return KiwiCore.iconIsSymbol(icon)
                ? .symbol(icon) : .text(icon)
        }
    }
}
