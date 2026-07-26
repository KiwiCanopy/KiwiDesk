import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Monitors (#68 §3.13): one row of equal-sized
/// monitor cards (physical x-order) plus the dashed
/// "Follows main display" card — the space chips live inside
/// the cards. Monitor fingerprints are a diagnostic and sit in
/// an Advanced disclosure.
struct MonitorsSection: View {
    @ObservedObject var model: SettingsModel
    @State private var advancedExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.editingStoredProfile
                    && !model.placementEditable
                {
                    // Editing a stored profile whose monitors
                    // aren't attached: no live geometry to
                    // render, so placement is read-only here
                    // (#18). The other sections still edit
                    // the profile.
                    placementUnavailable
                } else {
                    cardsSection
                    orphanPins
                    advancedSection
                }
            }
            .padding(16)
        }
    }

    private var cardsSection: some View {
        SettingsSection(
            L("monitors.space_placement", "Space placement")
        ) {
            if model.displays.isEmpty {
                Text(
                    L(
                        "monitors.none_detected",
                        "No monitors detected."
                    )
                )
                .foregroundStyle(.secondary)
            } else {
                Text(cardsCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 10) {
                    ForEach(orderedDisplays, id: \.id) {
                        display in
                        MonitorCard(
                            model: model,
                            display: display
                        )
                    }
                    MainRoleCard(model: model)
                }
            }
        }
    }

    private var cardsCaption: String {
        L(
            "monitors.cards.caption",
            "Drag a space between cards to pin it to "
                + "a monitor or have it follow the "
                + "main display. Dimmed spaces are "
                + "placed automatically. Right-click "
                + "a space for the same moves."
        )
    }

    /// Cards render connected displays; macOS's Displays pane
    /// owns true spatial arrangement — identity + order is
    /// enough here.
    private var orderedDisplays: [Display] {
        model.displays.sorted {
            $0.frame.minX < $1.frame.minX
        }
    }

    /// Pins to monitors that aren't attached right now — the
    /// user's intent must stay visible and clearable even
    /// though no card exists for the hardware.
    @ViewBuilder private var orphanPins: some View {
        let orphans = model.config.spacePins.filter {
            pin in
            !model.displays.contains {
                $0.fingerprint == pin.value
            }
        }
        .sorted { $0.key.raw < $1.key.raw }
        if !orphans.isEmpty {
            SettingsSection(
                L(
                    "monitors.orphan_pins.title",
                    "Pinned to disconnected monitors"
                )
            ) {
                ForEach(orphans, id: \.key.raw) { pin in
                    HStack {
                        SpaceChip(label: pin.key.raw)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(pin.value)
                            .font(
                                .system(
                                    .caption,
                                    design: .monospaced
                                )
                            )
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            model.config.spacePins[pin.key] =
                                nil
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .iconButtonAffordance(
                            L(
                                "monitors.orphan_pin.help",
                                "Back to automatic placement"
                            )
                        )
                    }
                }
            }
        }
    }

    private var placementUnavailable: some View {
        SettingsSection(
            L("monitors.space_placement", "Space placement")
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    L(
                        "monitors.not_connected",
                        "Monitors not connected"
                    ),
                    systemImage:
                        "display.trianglebadge.exclamationmark"
                )
                .font(.headline)
                Text(placementUnavailableCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var placementUnavailableCaption: String {
        L(
            "monitors.not_connected.caption",
            "This profile's monitors aren't attached "
                + "right now, so its space placement "
                + "can't be edited here. Connect its "
                + "monitor setup to arrange spaces — "
                + "the other sections still edit this "
                + "profile."
        )
    }

    /// Diagnostic, read-only, never touched day to day.
    private var advancedSection: some View {
        DisclosureGroup(isExpanded: $advancedExpanded) {
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
                ForEach(model.displays, id: \.id) { display in
                    fingerprintRow(display)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(
                L(
                    "monitors.advanced.title",
                    "Monitor fingerprints"
                )
            )
            .font(.headline)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
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
