import KiwiDeskCore
import SwiftUI

/// Live draft scene for the Looks & Animations detail panel
/// (#678, #1684): KiwiShelf's shape as the draft draws it, so a
/// look's click shows at a scale a sheen reads, then the colors
/// scene (`PaletteSceneThumbnail`).
struct PaletteScenePanel: View {
    @ObservedObject var model: SettingsModel

    private var settings: TilingSettings { model.config.settings }

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.currentScene,
            caption: PaletteSceneCaption.panel
        ) {
            VStack(spacing: 12) {
                shelfShape
                PaletteSceneThumbnail(
                    palette: ColorPalette(
                        name: "",
                        colors: ColorPaletteKeys.extract(from: settings)
                    ),
                    scene: .panel,
                    drawsBorder: model.config.settings.kiwishelf.border,
                    drawsSheen: model.config.settings.borderStyle.sheen
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// The shelf preview the Bars page draws, over the draft.
    private var shelfShape: some View {
        HomeCardBarsTile(
            settings: settings,
            spaceCount: model.config.spaces.count,
            scale: 1.8,
            spaceLabels: BarsPanelPreview.spaceLabels(
                spaces: model.config.spaces,
                icons: settings.spaceIcons
            )
        )
        .padding(12)
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SettingsTheme.previewPlate)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(SettingsTheme.planeRing, lineWidth: 1)
        )
        .environment(\.schematicPalette, HomeCardPlate.palette(settings))
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
