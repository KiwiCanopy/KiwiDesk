import KiwiDeskCore
import SwiftUI

/// Dormant layout overrides footer and reset controls (#290, #678 8b).
extension SpaceOverrideRows {
    /// Saved overrides for layouts other than active mode
    /// (`dormantOverrides`).
    var dormantLayouts: [(mode: LayoutMode, count: Int)] {
        g.dormantOverrides(for: space, active: mode)
    }

    /// Footer card summarizing and resetting dormant overrides for other
    /// layouts.
    @ViewBuilder
    var footer: some View {
        let dormant = dormantLayouts
        if !dormant.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                    Text(dormantSummary(dormant.count))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                    Spacer(minLength: 8)
                    resetAllButton
                }
                dormantDisclosure(dormant)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(SettingsTheme.sunken)
            )
        }
    }

    private func dormantSummary(_ count: Int) -> String {
        count == 1
            ? L(
                "space_override.dormant.summary_one",
                "Saved for 1 other layout — it applies if you "
                    + "switch this Space back."
            )
            : L(
                "space_override.dormant.summary_many",
                "Saved for %1$d other layouts — they apply if "
                    + "you switch this Space back.",
                count
            )
    }

    /// Inspection-only disclosure of dormant layout override counts (#956).
    @ViewBuilder
    private func dormantDisclosure(
        _ dormant: [(mode: LayoutMode, count: Int)]
    ) -> some View {
        DisclosureGroup(L("space_override.dormant.show", "Show")) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(dormant, id: \.mode) { entry in
                    Label(
                        dormantLine(entry.mode, entry.count),
                        systemImage: entry.mode.glyph
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .padding(.top, 4)
        }
        .disclosureGroupStyle(SettingsDisclosureStyle())
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var resetAllButton: some View {
        Button(
            L(
                "space_override.reset_all",
                "Reset All Layout Overrides"
            ),
            role: .destructive
        ) {
            pendingResetAll = space
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
    }

    private func dormantLine(
        _ layout: LayoutMode,
        _ count: Int
    ) -> String {
        count == 1
            ? L(
                "space_override.dormant.entry_one",
                "%1$@ — 1 field",
                layout.displayName
            )
            : L(
                "space_override.dormant.entry_many",
                "%1$@ — %2$d fields",
                layout.displayName,
                count
            )
    }
}
