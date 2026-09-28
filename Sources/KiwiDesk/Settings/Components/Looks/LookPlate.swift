import KiwiDeskCore
import SwiftUI

/// A look card's picture (#1684): the shelf preview drawn over the
/// draft with the look applied — the user's own Spaces and bars —
/// and a focused window wearing the ring the look's palette
/// colours, its sheen included: the owner ruled the card draws it
/// (2026-09-28), unlike the palette thumbnail, which leaves it undrawn
/// at tile scale (gui.md ▸ #753) — so the ring is drawn wide enough
/// for the ramp to read.
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
        // Hidden from VoiceOver, never from the pointer: the plate is
        // most of a card's Button label, so a click on it is the click.
        .accessibilityHidden(true)
    }

    /// A window in the desktop's well, ringed in the focus colour.
    private var focusedWindow: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(SettingsTheme.hairline)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        SheenPaint.style(
                            settings.borderStyle.focusedColor,
                            sheen: settings.borderStyle.sheen
                        ),
                        lineWidth: 3
                    )
            )
            .frame(width: 40, height: 22)
    }
}
