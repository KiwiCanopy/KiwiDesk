import KiwiDeskCore
import SwiftUI

/// Desktop preview scene for the Bars panel (#678, `HomeCardBarsTile`).
struct BarsPanelPreview: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if settings.bothBarsCanShow {
                framed(
                    showsAppBar: false,
                    caption: L(
                        "bars.preview.other_layouts",
                        "Other layouts"
                    )
                )
                framed(showsAppBar: true, caption: hostNames)
            } else {
                framed(showsAppBar: true, caption: nil)
            }
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

    private var settings: TilingSettings { model.config.settings }

    /// The layouts whose App Bar joins the Space Bar, in the
    /// order Core lists its hosts — the frame they share.
    private var hostNames: String {
        LayoutMode.allCases
            .filter { settings.appBarHost(for: $0)?.appBar.enabled == true }
            .map(\.displayName)
            .joined(separator: " · ")
    }

    /// One desktop frame. While both bars can show, the panel
    /// draws two — the Space Bar alone, and the two sharing the
    /// shelf — since no layout shows both pictures at once.
    private func framed(
        showsAppBar: Bool,
        caption: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeCardBarsTile(
                settings: settings,
                spaceCount: model.config.spaces.count,
                scale: 1.8,
                spaceLabels: spaceLabels,
                showsAppBar: showsAppBar
            )
            .padding(12)
            .frame(height: caption == nil ? 210 : 150)
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
                HomeCardPlate.palette(settings)
            )
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
            }
        }
    }

    private var spaceLabels: [SpaceGlyph] {
        Self.spaceLabels(
            spaces: model.config.spaces,
            icons: model.config.settings.spaceIcons
        )
    }

    /// Each Space's identifier as the bar draws it — Core's own
    /// ladder, never a reading of the preview's own (#1538).
    static func spaceLabels(
        spaces: [SpaceID],
        icons: [SpaceID: String]
    ) -> [SpaceGlyph] {
        spaces.map { KiwiCore.spaceIdentifier(id: $0, icon: icons[$0]) }
    }
}
