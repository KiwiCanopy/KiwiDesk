import KiwiDeskCore
import SwiftUI

/// Live draft colors scene for the Colours detail panel (#678,
/// `PaletteSceneThumbnail`).
struct PaletteScenePanel: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.colors.currentScene,
            caption: PaletteSceneCaption.panel
        ) {
            PaletteSceneThumbnail(
                palette: ColorPalette(
                    name: "",
                    colors: ColorPaletteKeys.extract(
                        from: model.config.settings
                    )
                ),
                scene: .panel
            )
            .frame(maxWidth: .infinity)
        }
    }
}
