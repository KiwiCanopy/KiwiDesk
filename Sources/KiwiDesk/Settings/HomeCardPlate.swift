import KiwiDeskCore
import SwiftUI

/// Full-bleed desktop preview plate atop profile Home cards (#786, 4g).
@MainActor
enum HomeCardPlate {
    /// Renders desktop plate view for supported profile destinations.
    static func plate(
        for destination: SettingsDestination,
        model: SettingsModel
    ) -> AnyView? {
        let settings = model.homeSettings
        switch destination {
        case .spaces:
            return tile(padding: 7, settings: settings) {
                HomeCardSpacesTile(model: model)
            }
        case .gapsAndBorders:
            return tile(padding: 4, settings: settings) {
                HomeCardGapsTile(settings: settings)
            }
        case .bars:
            return tile(padding: 7, settings: settings) {
                HomeCardBarsTile(
                    settings: settings,
                    pocketStands: model.pocketStandsAtRest,
                    spaceCount: model.config.spaces.count
                )
            }
        case .looks:
            return tile(padding: 11, settings: settings) {
                HomeCardColorsTile(settings: settings)
            }
        case .layoutDefaults:
            return tile(padding: 7, settings: settings) {
                HomeCardSchematicBand(
                    model: model,
                    height: interior(padding: 7) - 4,
                    readout: LayoutReadout.value(
                        for: LayoutUsage.mostUsed(
                            in: model.config
                        ),
                        settings: settings
                    )
                )
            }
        case .screens:
            return tile(padding: 8, settings: settings) {
                HomeCardScreensTile(model: model)
            }
        case .shortcuts, .profiles, .appRules, .kiwiVision, .ai,
            .general,
            .macChecklist:
            return nil
        }
    }

    /// Top margin air inside plate card (2026-08-09).
    static let topAir: CGFloat = 4

    /// Calculates available interior tile height for given padding.
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
                .deskPlate(settings, in: Rectangle())
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        )
    }
}

/// Scaled layout schematic preview band with headline parameter readout.
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
                        (palette ?? .unresolved).accent
                    )
            }
        }
    }
}

/// Headline number readout for layout mode parameter display (code review
/// 2026-08-09).
@MainActor
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
        case .monocle:
            // One window at a time; Monocle keeps no floor (#2237).
            return "1"
        case .scrolling:
            // The floor along the scroll axis, the one that applies.
            return L(
                "home.plate.readout.points",
                "%1$d pt",
                Int(
                    settings.minWindowSize(for: .scrolling, in: nil)
                        .along(
                            horizontal: settings.scrolling.axisIsHorizontal
                        )
                )
            )
        case .floating:
            return SettingsValueReadout.minSize(
                settings.minWindowSize(for: .floating, in: nil)
            )
        }
    }
}
