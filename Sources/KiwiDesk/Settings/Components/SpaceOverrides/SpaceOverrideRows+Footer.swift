import KiwiDeskCore
import SwiftUI

/// The per-space override editor's dormant footer (#290, restyled
/// for the #678 8b pane): the "Saved for other layouts" card — a
/// summary of overrides saved for layouts OTHER than the active
/// one, expandable to the per-layout breakdown, with `Reset All`
/// beside it. Split from `SpaceOverrideRows` to keep the base file
/// under the line ceiling. The active layout's own reset moved to
/// the editor header (`SpacesSection+Overrides.swift`); this footer
/// carries only what concerns the *other* layouts, so the card
/// reads as one idea.
extension SpaceOverrideRows {
    /// Layouts other than the active one that carry saved
    /// overrides for this space, each with its set-field count.
    /// Single-sourced from Core (`dormantOverrides`) over the same
    /// layout list the cell's count sums, so a counted layout can
    /// never be missing here. Internal so the editor chrome can
    /// gate the card on it.
    var dormantLayouts: [(mode: LayoutMode, count: Int)] {
        g.dormantOverrides(for: space, active: mode)
    }

    /// The bottom card, present only when dormant values exist. A
    /// clock glyph + "Saved for other layouts (N)" summary that
    /// says the values reactivate on a layout switch, a `Show`
    /// disclosure of the per-layout breakdown (inspection-only —
    /// no checkbox, accent or edit affordance, which is what reads
    /// "not editable here"), and the destructive `Reset All`
    /// (confirmed) that only this card can reach.
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

    /// A `DisclosureGroup` labelled `Show`, collapsed by default:
    /// the per-layout breakdown is inspection-only trivia. Each
    /// line is a glyph + "<Layout> — N fields", no interactive
    /// chrome.
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
