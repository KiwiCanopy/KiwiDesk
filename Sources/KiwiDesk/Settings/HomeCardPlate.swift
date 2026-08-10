import KiwiDeskCore
import SwiftUI

/// The dark desktop plate atop a profile-group Home card (#786):
/// a full-bleed picture of the user's desktop, drawn from the
/// draft in the user's palette (4g — brand describes the app,
/// profile colours describe the desktop). The plate sits ABOVE
/// the title and bleeds to the card's edges; the card's own
/// border and corner clip are its visible edge. The whole-app
/// cards never plate: their previews are data rows
/// (`HomeCardPreview`), not desktops.
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
            // Padding 4, not the family 11: the tile centres
            // its own 16:10 screen and the outer-gap readouts
            // inset from THAT outline, so the plate's frame
            // stays thin around it.
            return tile(padding: 4, settings: settings) {
                HomeCardGapsTile(settings: settings)
            }
        case .bars:
            return tile(padding: 7, settings: settings) {
                HomeCardBarsTile(
                    settings: settings,
                    spaceCount: model.config.spaces.count
                )
            }
        case .colors:
            return tile(padding: 11, settings: settings) {
                HomeCardColorsTile(settings: settings)
            }
        case .layoutDefaults:
            // The engine-backed schematic of the most-used mode
            // (G stays), carrying the prototype's number
            // readout — the mode's own headline value, so the
            // tile says "settings with numbers live here"
            // without a decorative sketch (owner, 2026-08-09).
            return tile(padding: 7, settings: settings) {
                HomeCardSchematicBand(
                    model: model,
                    // The interior minus 4 more: the schematic
                    // earns extra air to the plate's edge
                    // (owner, 2026-08-09) — derived, never a
                    // hand-summed copy of the paddings.
                    height: interior(padding: 7) - 4,
                    readout: LayoutReadout.value(
                        for: LayoutUsage.mostUsed(
                            in: model.config
                        ),
                        settings: settings
                    )
                )
            }
        case .monitors:
            return tile(padding: 8, settings: settings) {
                HomeCardMonitorsTile(model: model)
            }
        case .behavior:
            // Owner ruled the prototype's pictogram IN
            // (2026-08-09), made honest: the divider answers
            // the real mouse-resize choice.
            return tile(padding: 11, settings: settings) {
                HomeCardBehaviorTile(settings: settings)
            }
        case .advancedColors:
            return tile(padding: 11, settings: settings) {
                HomeCardSwatchGridTile(settings: settings)
            }
        case .shortcuts, .profiles, .appRules, .general:
            return nil
        }
    }

    /// The shared plate: fixed height, desktop-dark ground,
    /// the user's palette injected for every schematic inside,
    /// silent to VoiceOver — the renderers carry AX elements
    /// of their own (`SchematicCanvas`), a card is ONE button
    /// whose value is its subtitle, and a plate that voiced
    /// its parts would read the picture over the answer.
    /// Extra air under the card's top edge — at the uniform
    /// inset the tiles sat visibly close to it (owner,
    /// 2026-08-09). Named so the interior height derives.
    static let topAir: CGFloat = 4

    /// The room a tile's content actually gets at a given
    /// dispatch padding — the one derivation, so a band height
    /// cannot drift from the paddings it is carved from.
    static func interior(padding: CGFloat) -> CGFloat {
        SettingsTheme.plateHeight - padding * 2 - topAir
    }

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
                .padding(.top, Self.topAir)
                .frame(height: SettingsTheme.plateHeight)
                .frame(maxWidth: .infinity)
                .background(SettingsTheme.previewPlate)
                // 16b dark construction: the plate is fixed
                // dark and the card flips to within 1.07:1 of
                // it, so in dark this inset line is the only
                // seam. Transparent in light by the token.
                .overlay(
                    Rectangle().strokeBorder(
                        SettingsTheme.planeRing,
                        lineWidth: 1
                    )
                )
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
    /// `PaletteShelf.liveColors` lesson). Each colour passes
    /// the legibility floor first: the plate is KiwiDesk's
    /// fixed ground, so a user colour that sinks into it —
    /// legible on the user's own bar, invisible here — swaps
    /// for a theme fallback rather than drawing dark-on-dark
    /// (ui-designer, 2026-08-09).
    static func palette(
        _ settings: TilingSettings
    ) -> SchematicPalette {
        let accent = settings.spaceBarStyle.activeItemColor
        let ink = settings.appBarStyle.itemColor
        return SchematicPalette(
            accent: plateLegible(accent)
                ? Color(kiwiHex: accent)
                : SettingsTheme.accent,
            ink: plateLegible(ink)
                ? Color(kiwiHex: ink)
                : SettingsTheme.plateInk,
            base: SettingsTheme.previewPlate
        )
    }
}

/// The most-used layout's schematic, scaled from its fixed
/// `.tile` canvas into a plate band — scaled, never cropped
/// (the 13b picture-drawn-invisible class) — with the mode's
/// headline value as a mono readout in the plate's corner when
/// the caller passes one (the Layout Defaults card).
struct HomeCardSchematicBand: View {
    @ObservedObject var model: SettingsModel
    let height: CGFloat
    var readout: String?
    @Environment(\.schematicPalette) private var palette

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
        .overlay(alignment: .bottomLeading) {
            if let readout {
                Text(readout)
                    .font(
                        .system(
                            size: 8,
                            weight: .semibold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(
                        palette?.accent ?? SettingsTheme.accent
                    )
            }
        }
    }
}

/// The most-used mode's headline number — the value its own
/// editor leads with where that value is a number, and the
/// area's min-window default for the modes whose editors lead
/// with non-numeric controls (Scrolling's anchor picker,
/// Monocle and Floating). A tile carrying a number it cannot
/// explain still tells the truth: the number is the draft's,
/// and the area it opens shows the control it belongs to.
@MainActor
enum LayoutReadout {
    static func value(
        for mode: LayoutMode,
        settings: TilingSettings
    ) -> String {
        // Exhaustive on purpose: a `default` arm handed a new
        // mode the min-window readout silently; a new case must
        // decide its own number here (code review, 2026-08-09).
        switch mode {
        case .bsp:
            return String(
                format: "%.2f · %.2f",
                settings.bsp.splitRatioH,
                1 - settings.bsp.splitRatioH
            )
        case .stack:
            return String(
                format: "%.2f",
                settings.stack.masterRatio
            )
        case .grid:
            return "\(settings.grid.columns)×"
                + "\(settings.grid.rows)"
        case .track:
            return "\(settings.track.limit)"
        case .scrolling, .monocle, .floating:
            // A unit word is a translated frame, never a Swift
            // literal — `border.fit_gaps.unit` is the binding
            // precedent (localization-auditor, 2026-08-09).
            return L(
                "home.plate.readout.points",
                "%1$d pt",
                Int(settings.minWindowSize)
            )
        }
    }
}
