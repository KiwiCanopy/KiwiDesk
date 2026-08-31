import KiwiDeskCore
import SwiftUI

/// Data-row preview views for Whole App Home cards (#678, #786).
@MainActor
enum HomeCardPreview {
    /// Preview data view for given destination or nil (review 2026-08-04).
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
            return nil
        }
    }

    /// Maximum profile chips drawn before "+N" overflow chip.
    static let chipCap = 4

    /// Capsule chips of ordered profiles with overflow indicator
    /// (`OverflowSplit`, #859, #789).
    private static func profileChips(
        _ model: SettingsModel
    ) -> some View {
        let summaries = ProfilesFamilyRows.orderedProfiles(
            model.profileSummaries
        )
        let visible = OverflowSplit.shown(
            of: summaries.count,
            fitting: chipCap,
            withMarker: chipCap - 1
        )
        let shown = Array(summaries.prefix(visible))
        let overflow = max(summaries.count - shown.count, 0)
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
                                    : SettingsTheme.sunken
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
            .foregroundStyle(SettingsTheme.ink2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .strokeBorder(SettingsTheme.hairline)
            )
    }

    /// App icon wells for configured app rules (code review 2026-08-09).
    private static func ruleIcons(
        _ model: SettingsModel
    ) -> some View {
        let ids = Set(model.config.appRules.keys)
            .union(
                model.config.floatRules.map(
                    FloatFacet.appSegment(of:)
                )
            )
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
                        .foregroundStyle(SettingsTheme.ink2)
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

    /// Version label, the same frame the About pane renders.
    private static var versionLine: some View {
        Text(
            L(
                "general.version",
                "v%1$@",
                KiwiDeskVersion.semantic
            )
        )
        .font(.caption)
        .foregroundStyle(SettingsTheme.ink3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Key cap chips for default layer keybindings (owner ruling 2026-08-09).
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
                            size: 10.5,
                            weight: .semibold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(SettingsTheme.ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(SettingsTheme.sunken)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Renders combo string using key glyph pipeline (#23).
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
