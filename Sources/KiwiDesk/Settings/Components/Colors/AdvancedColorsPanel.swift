import KiwiDeskCore
import SwiftUI

/// Detail panel rendering every color simultaneously in one draft scene (#793,
/// `PaletteSceneThumbnail`, `PaletteSceneRoles`).
struct AdvancedColorsPanel: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection(
            SettingsCatalog.advancedColors.everyColorScene,
            caption: caption
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

    /// Shared draft scene caption (`PaletteSceneCaption`).
    private var caption: String { PaletteSceneCaption.panel }
}
