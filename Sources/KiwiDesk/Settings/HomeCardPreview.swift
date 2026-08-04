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

    /// The card's picture, or nil for the text-only cards —
    /// ONE switch, so "has a preview" and "which preview"
    /// cannot drift apart (review 2026-08-04: the earlier
    /// `hasPreview` twin was a second hand-kept copy of this
    /// partition). `AnyView` is the price of the optional; a
    /// card body mounts it at most once.
    static func preview(
        for destination: SettingsDestination,
        model: SettingsModel
    ) -> AnyView? {
        switch destination {
        case .spaces:
            return AnyView(
                nameChips(
                    model.config.spaces.map { "\($0)" },
                    cap: 6
                )
            )
        case .bars:
            return AnyView(barsStrip(model))
        case .layoutDefaults:
            return AnyView(schematics(model))
        case .monitors:
            return AnyView(miniArrangement(model))
        case .shortcuts:
            return AnyView(keyCaps(model))
        case .profiles:
            return AnyView(
                nameChips(
                    model.profileSummaries.map(\.name),
                    cap: 4
                )
            )
        case .appRules:
            return AnyView(
                nameChips(
                    model.config.appRules.keys.sorted(),
                    cap: 4
                )
            )
        case .gapsAndBorders, .colors, .advancedColors,
            .behavior, .general:
            return nil
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
        // SCALED, never cropped: the strip's canvas is a fixed
        // 96 pt, and a `maxHeight` + `clipped()` cut would keep
        // its middle band — with the default top-edge bar
        // cropped away, the card showed an empty plate (the
        // 13b "picture drawn invisible" class, review
        // 2026-08-04). ~0.55 lands the whole canvas inside the
        // 56 pt region; the empty caption override suppresses
        // the position caption, which the subtitle already
        // carries.
        return SpaceBarPreviewStrip(
            style: settings.spaceBarStyle,
            appBar: settings.appBarStyle,
            sameEdge: settings.spaceBarStyle.edge
                == settings.appBarStyle.edge,
            captionOverride: ""
        )
        .scaleEffect(0.55, anchor: .topLeading)
        .frame(height: height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
    }

    /// One schematic tile of the most-used layout mode — the
    /// engine-backed thumbnail family, never a sketch, and the
    /// mode from `LayoutUsage.mostUsed`, the one owner of that
    /// derivation (review 2026-08-04: a fourth inline copy had
    /// already diverged from it).
    private static func schematics(
        _ model: SettingsModel
    ) -> some View {
        LayoutSchematicView(
            mode: LayoutUsage.mostUsed(in: model.config),
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
