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
            "Drag a Space onto the display it belongs to."
        )
    }

    // MARK: - The picture

    /// The banner asks its census gate; the picture is its
    /// complement.
    ///
    /// ONE consult, not two: the cards carry no gate of their own
    /// (see `SettingKey+Monitors`), because a second, inverted
    /// copy of the banner's condition is a thing that can drift
    /// from it. So the `else` here is the complement by
    /// construction rather than a re-derivation.
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
            // What happens instead, not merely that the list is
            // empty (#678 Phase 4 pass 9, turn 18). Deliberately
            // modest about the cause: this fires when the display
            // enumeration comes back empty, which on a Mac with a
            // screen means the private path is unavailable rather
            // than that the hardware is gone — so the sentence
            // promises only what the fallback keeps doing, which
            // is tile on one space.
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
        // "Some", not "two": the predicate is true of any
        // duplicate count, three included.
        L(
            "monitors.picture.ambiguous",
            "Some of these displays look identical to KiwiDesk, "
                + "so a Space pinned to one may open on another."
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
