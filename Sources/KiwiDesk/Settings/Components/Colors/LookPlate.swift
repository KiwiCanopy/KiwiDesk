import KiwiDeskCore
import SwiftUI

/// A look card's picture (#1684): the shelf preview drawn over the
/// draft with the look applied — the user's own Spaces and bars —
/// and a focused window wearing the ring the look's palette
/// colours. The sheen is left undrawn at this scale, as the palette
/// thumbnail leaves it (gui.md ▸ #753); the detail panel draws it.
struct LookPlate: View {
    /// The draft with the look painted on.
    let settings: TilingSettings
    let spaceLabels: [SpaceGlyph]

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: PaletteSceneThumbnail.plateRadius
            )
            .fill(SettingsTheme.sunken)
            HomeCardBarsTile(
                settings: settings,
                spaceCount: spaceLabels.count,
                spaceLabels: spaceLabels
            )
            .overlay(focusedWindow)
            .padding(4)
            .environment(
                \.schematicPalette,
                HomeCardPlate.palette(settings)
            )
        }
        .frame(height: PaletteSceneThumbnail.baseHeight)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// A window in the desktop's well, ringed in the focus colour.
    private var focusedWindow: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(SettingsTheme.hairline)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(
                        Color(kiwiHex: settings.borderStyle.focusedColor),
                        lineWidth: 1.5
                    )
            )
            .frame(width: 34, height: 18)
    }
}
