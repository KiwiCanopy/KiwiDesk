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
        // The readout is ONE spoken element, the button a sibling
        // — combining an interactive child folds the clear action
        // into the label. The sentence keeps the space name
        // INSIDE it: a chip beside a prose fragment is a value
        // stitched by an HStack, which no translation can reorder
        // (docs review 2026-08-04).
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

    /// Formatted status sentence for a disconnected pin. Names
    /// no display, because the runtime does not promise one:
    /// `SpacePlacement.resolve` answers `.pinnedAbsent` with the
    /// positional default's assignment (docs review 2026-08-04).
    /// "Space %1$@" keeps the noun — a bare numeral opening a
    /// sentence is not writable in ja/ko.
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

    /// Row presenting display name and fingerprint (#540 rejected
    /// a per-row label as noise). VoiceOver is the case the drawer
    /// title does not cover — rows are stepped one at a time, so
    /// the row spoke a bare hex string: hence one combined element
    /// with an explicit spoken label, no visible change.
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
