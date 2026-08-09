import KiwiDeskCore
import SwiftUI

/// The dark desktop plate atop a profile-group Home card (#786):
/// a full-bleed picture of the user's desktop, drawn from the
/// draft in the user's palette (4g — brand describes the app,
/// profile colours describe the desktop). The plate sits ABOVE
/// the title and bleeds to the card's edges; the card's own
/// border and corner clip are its visible edge. Behaviour stays
/// plateless pending an owner ruling — its prototype pictogram
/// derives from no data — and the whole-app cards never plate:
/// their previews are data rows (`HomeCardPreview`), not
/// desktops.
@MainActor
enum HomeCardPlate {
    /// The card's plate, or nil for the plateless cards — ONE
    /// switch, like `HomeCardPreview.preview`, so "has a plate"
    /// and "which plate" cannot drift apart.
    static func plate(
        for destination: SettingsDestination,
        model: SettingsModel
    ) -> AnyView? {
        let settings = model.config.settings
        switch destination {
        case .spaces:
            return tile(padding: 7, settings: settings) {
                HomeCardSpacesTile(model: model)
            }
        case .gapsAndBorders:
            // Padding 4, not the family 11: the tile's own
            // per-edge insets ARE the outer-gap readout, so a
            // wide fixed frame would drown the value it shows.
            return tile(padding: 4, settings: settings) {
                HomeCardGapsTile(settings: settings)
            }
        case .bars:
            return tile(padding: 7, settings: settings) {
                HomeCardBarsTile(settings: settings)
            }
        case .colors:
            return tile(padding: 11, settings: settings) {
                HomeCardColorsTile(settings: settings)
            }
        case .layoutDefaults:
            // G stays (owner, 2026-08-09): the engine-backed
            // schematic of the most-used mode, never the
            // prototype's decorative ratio handles.
            return tile(padding: 7, settings: settings) {
                HomeCardSchematicBand(
                    model: model,
                    height: SettingsTheme.plateHeight - 14
                )
            }
        case .monitors:
            return tile(padding: 8, settings: settings) {
                HomeCardMonitorsTile(model: model)
            }
        case .advancedColors:
            return tile(padding: 11, settings: settings) {
                HomeCardSwatchGridTile(settings: settings)
            }
        case .behavior, .shortcuts, .profiles, .appRules,
            .general:
            return nil
        }
    }

    /// The shared plate: fixed height, desktop-dark ground, the
    /// user's palette injected for every schematic inside, and
    /// silent to VoiceOver — the renderers carry AX elements of
    /// their own (`SchematicCanvas`), and a card is ONE button
    /// whose value is its subtitle; a plate that voiced its
    /// parts would read the picture over the answer.
    private static func tile(
        padding: CGFloat,
        settings: TilingSettings,
        @ViewBuilder _ content: () -> some View
    ) -> AnyView {
        AnyView(
            content()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .padding(padding)
                .frame(height: SettingsTheme.plateHeight)
                .frame(maxWidth: .infinity)
                .background(SettingsTheme.previewPlate)
                .environment(
                    \.schematicPalette,
                    palette(settings)
                )
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        )
    }

    /// The user's palette folded to the three colours the
    /// pictures draw with: the Space Bar's active accent is the
    /// palette's primary voice, the App Bar's item ink its
    /// light ink, and the plate itself the opaque base under
    /// piles. Read off the style structs directly — cheap field
    /// reads, never `ColorPaletteKeys.extract` per card (the
    /// `PaletteShelf.liveColors` lesson).
    private static func palette(
        _ settings: TilingSettings
    ) -> SchematicPalette {
        SchematicPalette(
            accent: Color(
                kiwiHex: settings.spaceBarStyle.activeItemColor
            ),
            ink: Color(
                kiwiHex: settings.appBarStyle.itemColor
            ),
            base: SettingsTheme.previewPlate
        )
    }
}

/// The Spaces & Layouts picture: the Space Bar as a strip of
/// pips — one per declared space, in the bar's own colours,
/// only while the bar is enabled — over the most-used layout's
/// engine-backed schematic.
struct HomeCardSpacesTile: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        let style = model.config.settings.spaceBarStyle
        VStack(spacing: 5) {
            if style.enabled {
                strip(style)
            }
            HomeCardSchematicBand(
                model: model,
                height: style.enabled
                    ? SettingsTheme.plateHeight - 14 - 17
                    : SettingsTheme.plateHeight - 14
            )
        }
    }

    private func strip(_ style: SpaceBarStyle) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(kiwiHex: style.fillColor))
            .frame(height: 12)
            .overlay(
                HStack(spacing: 3) {
                    pips(style)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
            )
    }

    /// One pip per space, capped where the strip stops reading
    /// as countable; the first is the active one, as the bar
    /// draws a fresh session.
    private func pips(_ style: SpaceBarStyle) -> some View {
        let count = min(max(model.config.spaces.count, 1), 6)
        return ForEach(0..<count, id: \.self) { index in
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    Color(
                        kiwiHex: index == 0
                            ? style.activeItemColor
                            : style.itemColor
                    )
                )
                .frame(width: 9, height: 6)
        }
    }
}

/// The most-used layout's schematic, scaled from its fixed
/// `.tile` canvas into a plate band — scaled, never cropped
/// (the 13b picture-drawn-invisible class).
struct HomeCardSchematicBand: View {
    @ObservedObject var model: SettingsModel
    let height: CGFloat

    var body: some View {
        let factor = height / SchematicScale.tile.height
        LayoutSchematicView(
            mode: LayoutUsage.mostUsed(in: model.config),
            settings: model.config.settings,
            windows: 4,
            scale: .tile
        )
        .scaleEffect(factor)
        .frame(height: height)
    }
}
