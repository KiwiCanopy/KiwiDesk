import KiwiDeskCore
import SwiftUI

/// The two cards under the Monitors picture (#678 Phase 3, turn
/// 13b), split from `MonitorsSection` on the file ceiling: pins
/// waiting on hardware that is away, and the read-only
/// fingerprint drawer.
extension MonitorsSection {
    // MARK: - Pinned to a disconnected display

    /// Surfaced by its census gate, never by an inline predicate:
    /// `.orphanPinClear` declares `.runtime(.orphanPinsExist)`,
    /// and `MonitorsGates` is what answers it.
    ///
    /// The card exists because a pin to an absent monitor is the
    /// one placement the picture CANNOT show — there is no card
    /// for hardware that is not attached, so without this the
    /// user's own instruction would be invisible and unclearable
    /// until they plugged the monitor back in.
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
                // One sentence with the space name INSIDE it: a
                // chip beside a prose fragment would be a value
                // stitched by an `HStack`, which no translation
                // can reorder.
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
            Spacer()
            Button(backToAutomatic) {
                model.config.spacePins[orphan.space] = nil
            }
            .buttonStyle(.bordered)
        }
    }

    private func orphanSentence(_ space: SpaceID) -> String {
        L(
            "monitors.orphan_pin.sentence",
            "%1$@ is pinned to a monitor that isn't attached, "
                + "so it opens on the main display for now.",
            space.raw
        )
    }

    /// The chip's ⓧ tooltip and this button are the same offer,
    /// so they are the same key — a second one with near-identical
    /// English doubles the translation work and lets the two
    /// drift per locale with nothing to catch it. It is also the
    /// key the census names for this row.
    private var backToAutomatic: String {
        L(
            "monitors.orphan_pin.help",
            "Back to automatic placement"
        )
    }

    // MARK: - Monitor fingerprints

    /// Diagnostic, read-only, never touched day to day — how
    /// KiwiDesk recognises each display when it reconnects.
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

    /// One display's name and fingerprint. Visually the drawer's
    /// own title does the labelling — a visible per-row
    /// "Fingerprint" was tried and rejected as noise (#540), since
    /// by the time the eye reaches a row inside a drawer titled
    /// "Monitor fingerprints" nothing is ambiguous.
    ///
    /// **VoiceOver is the case that title does not cover:** it is
    /// read once, while rows are stepped one at a time, so the
    /// row used to speak a bare hex string with no context. Hence
    /// one combined element with an explicit spoken label, and no
    /// visible change.
    ///
    /// Selection stays scoped to the hash, so copying for a
    /// support ticket yields just the value.
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
        // One combined element with an explicit label: it also
        // overrides whatever spoken name the SF Symbol would
        // otherwise contribute.
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
