import KiwiDeskCore
import SwiftUI

/// The per-space override popover's footer (#290): a quiet
/// disclosure of overrides saved for *other* layouts, then the
/// reset buttons. Split from `SpaceOverrideRows` to keep the base
/// file under the line ceiling. Read order is edit-the-active-
/// layout → see-what-else-exists → reset, so the dormant
/// disclosure sits above the resets and motivates `Reset All`.
extension SpaceOverrideRows {
    @ViewBuilder
    var footer: some View {
        dormantDisclosure
        resetButtons
    }

    /// Layouts other than the active one that carry saved
    /// overrides for this space, each with its set-field count.
    /// Single-sourced from Core (`dormantOverrides`) over the same
    /// layout list the `Overrides (N)` count sums, so a counted
    /// layout can never be missing here.
    private var dormantLayouts: [(mode: LayoutMode, count: Int)] {
        g.dormantOverrides(for: space, active: mode)
    }

    /// A `DisclosureGroup`, collapsed by default: dormant values
    /// are inspection-only trivia, so they don't spend the capped
    /// popover's vertical budget unless asked. Each line is a
    /// glyph + "<Layout> — N fields" with no checkbox, accent, or
    /// chevron — that absence of interactive chrome is what reads
    /// "not editable here" without a caption saying so.
    @ViewBuilder
    private var dormantDisclosure: some View {
        let dormant = dormantLayouts
        if !dormant.isEmpty {
            DisclosureGroup(
                L(
                    "space_override.dormant.label",
                    "Saved for other layouts (%1$d)",
                    dormant.count
                )
            ) {
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
                .padding(.top, 2)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
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

    /// `Reset <Layout> Overrides` (always present, greyed when the
    /// active layout has none — furniture of the active section,
    /// so "grey, don't hide") and, only when dormant values exist,
    /// the destructive `Reset All Layout Overrides` (confirmed).
    @ViewBuilder
    private var resetButtons: some View {
        Divider()
            .padding(.top, 4)
        Button(
            L(
                "space_override.reset_active",
                "Reset %1$@ Overrides",
                mode.displayName
            ),
            role: .destructive
        ) {
            model.config.settings.resetOverride(mode, for: space)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(
            gates.inertReason(for: .spaces(.spaceOverrideResetActive))
                != nil
        )
        .help(
            gates.inertReason(for: .spaces(.spaceOverrideResetActive))
                .map(SpacesGateHelp.sentence) ?? ""
        )

        if !dormantLayouts.isEmpty {
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
        }
    }
}
