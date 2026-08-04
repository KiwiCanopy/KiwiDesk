import KiwiDeskCore
import SwiftUI

/// Monitors (#68 §3.13, rebuilt in #678 Phase 3 turn 13b): the
/// one page that is a picture rather than a form.
///
/// The cards used to be an equal-sized row in physical x-order —
/// identity and order, with the geometry thrown away. They are
/// now the real arrangement: each display drawn at its own size
/// and position (`MonitorArrangement`), so the answer to "which
/// monitor is that?" is where the card is, not what it says.
///
/// Everything else on the page hangs off that picture: the
/// follows-main tray on the main display, a warning card for pins
/// waiting on absent hardware, and the read-only fingerprints
/// drawer (both in `MonitorsSection+Details`).
struct MonitorsSection: View {
    @ObservedObject var model: SettingsModel
    /// `internal`, not `private`: the drawer that owns this
    /// state is drawn in `MonitorsSection+Details.swift` (file
    /// ceiling), and `@State` cannot move to an extension.
    @State var advancedExpanded = false
    /// Which display's contents the readout under the picture
    /// describes. View state, never config — selecting a display
    /// changes nothing about the setup.
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
            "Drag a space onto the display it belongs to."
        )
    }

    // MARK: - The picture

    /// The picture and the banner that stands in for it are two
    /// rows of one container, each asking its OWN census gate —
    /// `MonitorsGates` is what keeps them from both appearing or
    /// both vanishing, rather than an `if/else` here that would
    /// be a second copy of the condition.
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
            }
            if gates.inertReason(for: .monitors(.spacePins))
                == nil
            {
                picture(rows: rows, gates: gates)
            }
        }
    }

    @ViewBuilder private func picture(
        rows: MonitorsFamilyRows,
        gates: MonitorsGates
    ) -> some View {
        if rows.displays.isEmpty {
            Text(
                L(
                    "monitors.none_detected",
                    "No monitors detected."
                )
            )
            .foregroundStyle(.secondary)
        } else {
            MonitorsPicture(
                model: model,
                rows: rows,
                selection: $selection,
                showsTray: gates.inertReason(
                    for: .monitors(.mainSpaces)
                ) == nil
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

    /// Said rather than left to be noticed: past the ratio cap
    /// the biggest display is drawn smaller than true scale, so
    /// the smallest stays big enough to drop a space onto. A
    /// picture that quietly lies about proportion reads as a
    /// wrong arrangement.
    ///
    /// Below the picture, not above it — the caption that opens
    /// the page is what to DO here, and a caveat about drawing
    /// cannot outrank it. And only while the difference is
    /// visible: `MonitorArrangement.perceptibleClamp` is what
    /// keeps this off the commonest two-display desk, whose 2.54
    /// ratio trips the cap by 1.6%.
    private var clampedNote: String {
        L(
            "monitors.picture.clamped",
            "Sizes are approximate — these displays are too "
                + "different to draw to scale."
        )
    }

    /// Two monitors of the same model and resolution have the
    /// same fingerprint, which is what a pin is stored against —
    /// so KiwiDesk genuinely cannot tell them apart, and the
    /// picture would otherwise show the same spaces on both cards
    /// with no explanation. The list this page replaced hid the
    /// symptom; a picture cannot.
    private var ambiguousNote: String {
        L(
            "monitors.picture.ambiguous",
            "Two of these displays look identical to KiwiDesk, "
                + "so a space pinned to one may open on either."
        )
    }

    /// What the selected display currently holds. Nothing is
    /// selected at rest — the picture already says where every
    /// space sits, and this answers the one thing it cannot: what
    /// is on that screen right now.
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
            held: rows.chips(on: display.fingerprint).count,
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
            "This profile's monitors aren't attached "
                + "right now, so its space placement "
                + "can't be edited here. Connect its "
                + "monitor setup to arrange spaces — "
                + "the other sections still edit this "
                + "profile."
        )
    }
}
