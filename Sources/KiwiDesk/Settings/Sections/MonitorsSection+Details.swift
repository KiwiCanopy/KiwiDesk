import KiwiDeskCore
import SwiftUI

/// Secondary cards for Monitors settings (#678 Phase 3, turn 13b).
extension MonitorsSection {
    /// Card displaying spaces pinned to absent displays (`MonitorsGates`).
    @ViewBuilder func orphanCard(
        rows: MonitorsFamilyRows,
        gates: MonitorsGates
    ) -> some View {
        if gates.inertReason(for: .monitors(.orphanPinClear))
            == nil
        {
            SettingsSection(
                SettingsCatalog.monitors.orphanPins
            ) {
                ForEach(rows.orphans) { orphan in
                    orphanRow(orphan)
                }
            }
        }
    }

    private func orphanRow(_ orphan: OrphanPin) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(orphanSentence(orphan.space))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text(orphan.fingerprint)
                    .font(
                        .system(.caption, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                L(
                    "monitors.orphan_pin.row_axlabel",
                    "%1$@, waiting for monitor %2$@",
                    orphanSentence(orphan.space),
                    orphan.fingerprint
                )
            )
            Spacer()
            Button(backToAutomatic) {
                model.config.spacePins[orphan.space] = nil
            }
            .settingsActionButton()
        }
    }

    /// Formatted status sentence for disconnected space pin
    /// (`SpacePlacement.resolve`, docs review 2026-08-04).
    private func orphanSentence(_ space: SpaceID) -> String {
        L(
            "monitors.orphan_pin.sentence",
            "Space %1$@ is pinned to a monitor that isn't "
                + "attached, so it opens elsewhere for now.",
            space.raw
        )
    }

    /// Label key for resetting space pin to automatic placement.
    private var backToAutomatic: String {
        L(
            "monitors.clear_pin.label",
            "Back to automatic placement"
        )
    }

    /// Read-only monitor hardware identification drawer.
    func fingerprintsDrawer(
        rows: MonitorsFamilyRows
    ) -> some View {
        SettingsDisclosure(
            SettingsCatalog.monitors.monitorFingerprints,
            chrome: .card,
            isExpanded: $advancedExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    L(
                        "monitors.advanced.caption",
                        "Profiles reattach automatically when "
                            + "a known monitor setup is "
                            + "reconnected."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                ForEach(rows.orderedDisplays, id: \.id) {
                    display in
                    fingerprintRow(display)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Row presenting display name and hardware fingerprint (#540).
    private func fingerprintRow(_ display: Display) -> some View {
        HStack {
            Image(systemName: "display")
                .foregroundStyle(.secondary)
            Text(display.name)
            Spacer()
            Text(display.fingerprint)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L(
                "monitors.advanced.row_axlabel",
                "%1$@, fingerprint %2$@",
                display.name,
                display.fingerprint
            )
        )
    }
}
