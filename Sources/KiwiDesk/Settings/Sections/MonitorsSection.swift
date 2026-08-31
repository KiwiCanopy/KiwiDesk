import KiwiDeskCore
import SwiftUI

/// Monitors configuration and visual arrangement view
/// (#68 §3.13, #678 Phase 3 turn 13b, `MonitorArrangement`).
struct MonitorsSection: View {
    @ObservedObject var model: SettingsModel
    @State var advancedExpanded = false
    @State var selection: DisplayID?

    var body: some View {
        let rows = model.monitorRows
        let gates = MonitorsGates(
            editingStoredProfile: model.editingStoredProfile,
            placementEditable: model.placementEditable,
            hasOrphanedPins: !rows.orphans.isEmpty
        )
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(areaCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                placementCard(rows: rows, gates: gates)
                orphanCard(rows: rows, gates: gates)
                fingerprintsDrawer(rows: rows)
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    private var areaCaption: String {
        L(
            "monitors.area.caption",
            "Drag a Space onto the display it belongs to."
        )
    }

    /// Renders placement canvas or unavailable state (`SettingKey+Monitors`).
    @ViewBuilder private func placementCard(
        rows: MonitorsFamilyRows,
        gates: MonitorsGates
    ) -> some View {
        SettingsSection(
            SettingsCatalog.monitors.spacePlacement
        ) {
            if gates.inertReason(
                for: .monitors(.placementUnavailable)
            ) == nil {
                placementUnavailable
            } else {
                picture(rows: rows)
            }
        }
    }

    @ViewBuilder private func picture(
        rows: MonitorsFamilyRows
    ) -> some View {
        if rows.displays.isEmpty {
            Text(
                L(
                    "monitors.none_detected",
                    "No monitors detected, so there's nothing to "
                        + "place Spaces on. Windows still tile, "
                        + "all in a single Space."
                )
            )
            .foregroundStyle(.secondary)
        } else {
            MonitorsPicture(
                model: model,
                rows: rows,
                selection: $selection
            )
            if MonitorArrangement.isApproximate(rows.displays) {
                note(clampedNote)
            }
            if rows.hasAmbiguousDisplays {
                note(ambiguousNote)
            }
            selectionReadout(rows: rows)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Note shown when display ratios are clamped
    /// (`MonitorArrangement.perceptibleClamp`).
    private var clampedNote: String {
        L(
            "monitors.picture.clamped",
            "Sizes are approximate — these displays are too "
                + "different to draw to scale."
        )
    }

    /// Note shown when multiple displays share identical hardware
    /// fingerprints.
    private var ambiguousNote: String {
        L(
            "monitors.picture.ambiguous",
            "Some of these displays look identical to KiwiDesk, "
                + "so a Space pinned to one may open on another."
        )
    }

    /// Description of spaces assigned to selected display.
    @ViewBuilder private func selectionReadout(
        rows: MonitorsFamilyRows
    ) -> some View {
        if let display = rows.displays.first(where: {
            $0.id == selection
        }) {
            Text(readout(for: display, rows: rows))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func readout(
        for display: Display,
        rows: MonitorsFamilyRows
    ) -> String {
        MonitorReadout.sentence(
            held: rows.held(
                on: display,
                isMain: model.mainDisplay?.id == display.id
            ),
            showing: model.showingSpace(on: display.id)
        )
    }

    private var placementUnavailable: some View {
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

    private var placementUnavailableCaption: String {
        L(
            "monitors.not_connected.caption",
            "This profile's screens aren't attached "
                + "right now, so its %1$@ "
                + "can't be edited here. Connect its "
                + "screen setup to arrange Spaces — "
                + "the other sections still edit this "
                + "profile.",
            L("monitors.space_placement", "Space placement")
        )
    }
}
