import KiwiDeskCore
import SwiftUI

/// The data-row half of a Home card's picture (#678 turn 9,
/// re-cut in #786): the whole-app cards' previews, drawn only
/// from the real draft — a card is a mirror, not an
/// illustration. The profile-group cards moved their pictures
/// to the desktop plate (`HomeCardPlate`); what stays here are
/// rows of data — key caps, profile chips, app icons, the
/// version — that belong beside the title, not on a desktop.
@MainActor
enum HomeCardPreview {
    /// The card's data row, or nil for the cards with none —
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
        case .shortcuts:
            return AnyView(keyCaps(model))
        case .profiles:
            return AnyView(profileChips(model))
        case .appRules:
            return AnyView(ruleIcons(model))
        case .general:
            return AnyView(versionLine)
        case .spaces, .bars, .layoutDefaults, .monitors,
            .gapsAndBorders, .colors, .advancedColors,
            .behavior:
            // The profile group draws on the plate or not at
            // all (`HomeCardPlate.plate` is that partition's
            // one switch).
            return nil
        }
    }

    // MARK: - Pieces

    /// Capsule chips of the real profile names, the default one
    /// inverted — the answer "which one wins" read without the
    /// subtitle — capped with a "+N" chip that is a label, not
    /// an affordance.
    private static func profileChips(
        _ model: SettingsModel
    ) -> some View {
        let summaries = model.profileSummaries
        let shown = Array(summaries.prefix(4))
        let overflow = summaries.count - shown.count
        return HStack(spacing: 4) {
            ForEach(shown, id: \.name) { summary in
                Text(summary.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(
                        summary.isDefault
                            ? SettingsTheme.card
                            : SettingsTheme.ink
                    )
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                summary.isDefault
                                    ? SettingsTheme.ink
                                    : Color.primary
                                        .opacity(0.07)
                            )
                    )
            }
            if overflow > 0 {
                overflowChip(overflow)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func overflowChip(_ count: Int) -> some View {
        Text("+\(count)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.2))
            )
    }

    /// The ruled apps' real icons in small wells — through the
    /// memoized cache the App Rules rows warm, never a raw
    /// `NSWorkspace` read per card — with a "+N" well for the
    /// rest. Union of both rule kinds, the same pair the
    /// subtitle counts.
    private static func ruleIcons(
        _ model: SettingsModel
    ) -> some View {
        let ids = Set(model.config.appRules.keys)
            .union(model.config.floatRules)
            .sorted()
        let shown = Array(ids.prefix(5))
        let overflow = ids.count - shown.count
        return HStack(spacing: 4) {
            ForEach(shown, id: \.self) { id in
                well {
                    Image(
                        nsImage: AppIconCache.shared.icon(
                            forBundleID: id
                        )
                    )
                    .resizable()
                    .frame(width: 16, height: 16)
                }
            }
            if overflow > 0 {
                well {
                    Text("+\(overflow)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func well(
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(SettingsTheme.sunken)
            .frame(width: 22, height: 22)
            .overlay(content())
    }

    /// The version the About row states, through the one shared
    /// derivation, so the card can never disagree with the area
    /// it opens.
    private static var versionLine: some View {
        Text(
            L(
                "home.card.general.version",
                "v%1$@",
                KiwiDeskVersion.displayString
            )
        )
        .font(.caption)
        .foregroundStyle(SettingsTheme.ink3)
        .frame(maxWidth: .infinity, alignment: .leading)
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
