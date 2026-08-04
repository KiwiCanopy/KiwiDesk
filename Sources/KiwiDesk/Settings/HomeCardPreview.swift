import KiwiDeskCore
import SwiftUI

/// The picture half of a Home card (#678 turn 9), drawn only
/// from renderers that already exist and already ask the real
/// data — a card is a mirror, not an illustration. Cards with
/// nothing spatial to show return nil and stay text-only; the
/// Phase 4 draft renderer is what upgrades the profile cards to
/// the digest's dark preview tile.
@MainActor
enum HomeCardPreview {
    /// The preview region's fixed height, so grid rows align.
    static let height: CGFloat = 56

    @ViewBuilder
    static func preview(
        for destination: SettingsDestination,
        model: SettingsModel
    ) -> some View {
        switch destination {
        case .spaces:
            nameChips(
                model.config.spaces.map { "\($0)" },
                cap: 6
            )
        case .bars:
            barsStrip(model)
        case .layoutDefaults:
            schematics(model)
        case .monitors:
            miniArrangement(model)
        case .shortcuts:
            keyCaps(model)
        case .profiles:
            nameChips(
                model.profileSummaries.map(\.name),
                cap: 4
            )
        case .appRules:
            nameChips(
                model.config.appRules.keys.sorted(),
                cap: 4
            )
        case .gapsAndBorders, .colors, .advancedColors,
            .behavior, .general:
            EmptyView()
        }
    }

    /// Whether the card draws a picture at all — nil-preview
    /// cards give the row to the subtitle.
    static func hasPreview(
        _ destination: SettingsDestination
    ) -> Bool {
        switch destination {
        case .spaces, .bars, .layoutDefaults, .monitors,
            .shortcuts, .profiles, .appRules:
            return true
        case .gapsAndBorders, .colors, .advancedColors,
            .behavior, .general:
            return false
        }
    }

    // MARK: - Pieces

    /// Capsule chips of real names, capped with a "+N" chip —
    /// the +N is a label, not an affordance.
    @ViewBuilder
    private static func nameChips(
        _ names: [String],
        cap: Int
    ) -> some View {
        let shown = Array(names.prefix(cap))
        let overflow = names.count - shown.count
        HStack(spacing: 4) {
            ForEach(shown, id: \.self) { name in
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.07))
                    )
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .strokeBorder(
                                Color.primary.opacity(0.2)
                            )
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    /// The live bar strip — the same render the Bars editor
    /// leads with, so Plain draws no plate and thickness moves
    /// the strip on the card too.
    private static func barsStrip(
        _ model: SettingsModel
    ) -> some View {
        let settings = model.config.settings
        return SpaceBarPreviewStrip(
            style: settings.spaceBarStyle,
            appBar: settings.appBarStyle,
            sameEdge: settings.spaceBarStyle.edge
                == settings.appBarStyle.edge,
            captionOverride: ""
        )
        .frame(maxHeight: height)
        .clipped()
        .allowsHitTesting(false)
    }

    /// One schematic tile of the most-used layout mode — the
    /// engine-backed thumbnail family, never a sketch.
    private static func schematics(
        _ model: SettingsModel
    ) -> some View {
        let modes = model.config.spaces.map {
            model.config.spaceModes[$0] ?? .bsp
        }
        let counts = Dictionary(grouping: modes) { $0 }
        let lead =
            counts.max {
                $0.value.count < $1.value.count
            }?.key ?? .bsp
        return LayoutSchematicView(
            mode: lead,
            settings: model.config.settings,
            windows: 4,
            scale: .tile
        )
        .scaleEffect(0.62, anchor: .topLeading)
        .frame(height: height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
    }

    /// The real display set, shrunk: the same arrangement maths
    /// as the Monitors picture, so the card mirrors the screen
    /// it opens. Read-only rectangles — the draggable chips
    /// stay on the area screen.
    private static func miniArrangement(
        _ model: SettingsModel
    ) -> some View {
        let mainID = PositionalDisplays.liveMainID
        return GeometryReader { proxy in
            let layout = MonitorArrangement.layout(
                displays: model.displays,
                mainID: mainID,
                canvas: proxy.size
            )
            ZStack(alignment: .topLeading) {
                ForEach(layout.displays) { drawn in
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            drawn.display.id == mainID
                                ? Color.accentColor
                                : Color.secondary.opacity(0.6),
                            lineWidth: 1.5
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    Color.primary.opacity(0.05)
                                )
                        )
                        .frame(
                            width: drawn.rect.width,
                            height: drawn.rect.height
                        )
                        .offset(
                            x: drawn.rect.minX,
                            y: drawn.rect.minY
                        )
                }
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
    }

    /// The first few default-layer combos as native key caps,
    /// through the same glyph pipeline the recorder displays
    /// with.
    @ViewBuilder
    private static func keyCaps(
        _ model: SettingsModel
    ) -> some View {
        let combos =
            model.config.layers
            .first { $0.isDefault }?
            .bindings.prefix(4)
            .map(\.combo) ?? []
        HStack(spacing: 4) {
            ForEach(combos, id: \.self) { combo in
                Text(capText(combo))
                    .font(
                        .system(
                            size: 11,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                Color.primary.opacity(0.15)
                            )
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The recorder's own combo rendering (#23): glyphs mapped
    /// through the active keyboard layout, raw string on a
    /// parse failure.
    private static func capText(_ combo: String) -> String {
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }
}
