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
                HomeCardBarsTile(settings: settings)
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
                    // −22, not the padding's −14: the schematic
                    // earns extra air to the plate's edge
                    // (owner, 2026-08-09).
                    height: SettingsTheme.plateHeight - 22,
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
                // Every picture takes extra air under the
                // card's top edge — at the uniform inset alone
                // the tiles sat visibly close to it (owner,
                // 2026-08-09, on device).
                .padding(.top, 4)
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
    /// `PaletteShelf.liveColors` lesson). Each colour passes
    /// the legibility floor first: the plate is KiwiDesk's
    /// fixed ground, so a user colour that sinks into it —
    /// legible on the user's own bar, invisible here — swaps
    /// for a theme fallback rather than drawing dark-on-dark
    /// (ui-designer, 2026-08-09).
    private static func palette(
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

/// The Spaces & Layouts picture: a FAN of mini-desktops, one
/// per declared space in the draft's order, the active one
/// forward and fully exposed in the palette accent, the rest
/// ghosted behind it (ui-designer concept round, 2026-08-09 —
/// over the schematic band, which duplicated the Layout
/// Defaults card's picture). The fan reuses the Monocle
/// schematic's several-full-screens-one-current vocabulary;
/// interiors stay blank because the app has no per-layout
/// glyph — the schematic IS a layout's label, and a 20 pt one
/// is the 13b class. Position, exposure, fill density and
/// stroke weight all step, so hue never carries alone; past
/// the cap the family's "+N" grammar says so.
struct HomeCardSpacesTile: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.schematicPalette) private var palette

    // 16:10 landscape panes, not tall slabs — each pane is a
    // SCREEN (owner, 2026-08-09) — centred on both axes so the
    // first pane's leading margin equals the last one's
    // trailing margin.
    private static let card = CGSize(width: 70, height: 44)
    private static let exposed: CGFloat = 18
    private static let cap = 8

    var body: some View {
        let total = max(model.config.spaces.count, 1)
        let count = min(total, Self.cap)
        HStack(spacing: 6) {
            fan(count)
            if total > count {
                Text("+\(total - count)")
                    .font(
                        .system(size: 9, weight: .semibold)
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        palette?.ink ?? SettingsTheme.plateInk
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fan(_ count: Int) -> some View {
        ZStack(alignment: .leading) {
            ForEach(0..<count, id: \.self) { index in
                pane(active: index == 0)
                    .offset(
                        x: CGFloat(index) * Self.exposed
                    )
                    .zIndex(Double(-index))
            }
        }
        .frame(
            width: Self.card.width
                + CGFloat(count - 1) * Self.exposed,
            height: Self.card.height,
            // Leading, not the frame default: the ZStack's own
            // layout size is ONE pane (offsets are drawing
            // only), so a centre-aligned frame shifted the
            // whole run half a fan to the right — the first
            // screen started mid-plate (owner, 2026-08-09).
            alignment: .leading
        )
    }

    private func pane(active: Bool) -> some View {
        // Hoisted picks: the chained ternaries over optional
        // chains blew the type-checker's budget inline (the
        // shallow-body rule's CI-only failure class).
        let base: Color =
            palette?.base ?? SettingsTheme.previewPlate
        let fill: Color =
            active
            ? palette?.fill ?? LayoutSchematic.fill
            : palette?.ghostFill ?? Color.secondary.opacity(0.15)
        let stroke: Color =
            active
            ? palette?.stroke ?? LayoutSchematic.stroke
            : palette?.ghostStroke
                ?? Color.secondary.opacity(0.5)
        // Opaque base first: the ghosts overlap, and
        // translucent fills would sum where they do (the
        // #712 compounding trap).
        return RoundedRectangle(cornerRadius: 5)
            .fill(base)
            .overlay(
                RoundedRectangle(cornerRadius: 5).fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        stroke,
                        lineWidth: active ? 1.5 : 1
                    )
            )
            .frame(
                width: Self.card.width,
                height: Self.card.height
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
/// editor leads with, formatted as the editor formats it. A
/// tile carrying a number it cannot explain still tells the
/// truth: the number is the draft's, and the area it opens
/// shows the control it belongs to.
enum LayoutReadout {
    static func value(
        for mode: LayoutMode,
        settings: TilingSettings
    ) -> String {
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
        default:
            return "\(Int(settings.minWindowSize)) pt"
        }
    }
}
