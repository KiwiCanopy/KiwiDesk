import Foundation
import KiwiDeskCore
import SwiftUI

/// Screens configuration and visual arrangement view
/// (#68 §3.13, #678 Phase 3 turn 13b, `ScreenArrangement`).
struct ScreensSection: View {
    @ObservedObject var model: SettingsModel
    @State var advancedExpanded = false
    @State var selection: ScreenSelection?
    @State var renameRequest: AreaRenameRequest?
    @State var sizesRequest: AreaSizesRequest?
    /// The area giving way while Adjust… is open (#3517 ruling 26).
    @State var givingWay: Set<ScreenSelection> = []
    /// The pane a menu's Split or Merge hands focus to, since the
    /// focused pane may be the one merged away.
    @State var paneFocus: ScreenSelection?

    var body: some View {
        let rows = model.screenRows
        let gates = ScreensGates(
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
            .padding(.horizontal, SettingsMetrics.paneInset)
            .settingsPageBottom()
        }
        .onChange(of: model.config.settings.displayAreas) {
            selection = normalized(selection, rows: model.screenRows)
        }
    }

    private var areaCaption: String {
        L(
            "monitors.picture.caption",
            "Drag a Space onto the screen it belongs to."
        )
    }

    /// Renders placement canvas or unavailable state. ONE gate
    /// consult, not two: the cards carry no gate of their own
    /// (`SettingKey+Screens`) — the `else` is the banner's
    /// complement by construction, never an inverted copy that
    /// can drift.
    @ViewBuilder private func placementCard(
        rows: ScreensFamilyRows,
        gates: ScreensGates
    ) -> some View {
        SettingsSection(
            SettingsCatalog.screens.spacePlacement
        ) {
            if gates.inertReason(
                for: .screens(.placementUnavailable)
            ) == nil {
                placementUnavailable
            } else {
                picture(rows: rows)
            }
        }
    }

    @ViewBuilder private func picture(
        rows: ScreensFamilyRows
    ) -> some View {
        if rows.displays.isEmpty {
            Text(
                L(
                    "monitors.none_detected",
                    "No screens detected, so there's nothing to "
                        + "place Spaces on. Windows still tile, "
                        + "all in a single Space."
                )
            )
            .foregroundStyle(.secondary)
        } else {
            ScreensPicture(
                model: model,
                rows: rows,
                selection: $selection,
                givingWay: givingWay,
                paneFocus: paneFocus,
                act: act
            )
            if ScreenArrangement.isApproximate(rows.displays) {
                note(clampedNote)
            }
            if rows.hasAmbiguousDisplays {
                note(ambiguousNote)
            }
            ScreenShiftNote(model: model)
            selectionReadout(rows: rows)
            selectionEditor(rows: rows)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Note shown when screen ratios are clamped — said rather
    /// than left to be noticed: a picture that quietly lies about
    /// proportion reads as a wrong arrangement. Shown only while
    /// the difference is visible
    /// (`ScreenArrangement.perceptibleClamp` keeps it off the
    /// common two-screen desk).
    private var clampedNote: String {
        L(
            "monitors.picture.clamped",
            "Sizes are approximate — these screens are too "
                + "different to draw to scale."
        )
    }

    /// Note shown when screens share one fingerprint (same model
    /// and resolution) — which is what a pin is stored against, so
    /// KiwiDesk genuinely cannot tell them apart; the picture
    /// would otherwise show the same spaces on both cards
    /// unexplained. "Some", not "two": true of any duplicate
    /// count.
    private var ambiguousNote: String {
        L(
            "monitors.picture.ambiguous",
            "Some of these screens look identical to KiwiDesk, "
                + "so a Space pinned to one may open on another."
        )
    }

    /// Description of spaces assigned to the selected screen or
    /// area.
    @ViewBuilder private func selectionReadout(
        rows: ScreensFamilyRows
    ) -> some View {
        if let display = rows.displays.first(where: {
            $0.id == selection?.display
        }) {
            Text(readout(for: display, rows: rows))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func readout(
        for display: Display,
        rows: ScreensFamilyRows
    ) -> String {
        let key = ScreenAreaKey(
            fingerprint: display.fingerprint,
            areaID: selection?.area ?? 0
        ).description
        return ScreenReadout.sentence(
            held: rows.held(
                on: key,
                isMain: model.mainDisplay?.id == display.id
            ),
            // Only the first area says which Space is showing, as
            // its pane does (`ScreenAreaPane.readout`).
            showing: (selection?.area ?? 0) == 0
                ? model.showingSpace(on: display.id) : nil
        )
    }

    /// The selection's editor (#3517 ruling 24), which leaves with
    /// the selection: a selection is not a mode.
    @ViewBuilder private func selectionEditor(
        rows: ScreensFamilyRows
    ) -> some View {
        Divider()
        // A search hit lands here, on the editor or its hint (#3616).
        Group {
            if let display = rows.displays.first(where: {
                $0.id == selection?.display
            }) {
                ScreenAreaEditor(
                    model: model,
                    display: display,
                    area: selection?.area,
                    rename: $renameRequest,
                    sizes: $sizesRequest,
                    givingWay: $givingWay,
                    percent: $model.nav.areaSizesInPercent,
                    select: { selection = $0 }
                )
            } else {
                Text(
                    L(
                        "monitors.selection.hint",
                        "Click a screen or an area to split, merge or "
                            + "rename it."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .searchAnchored(SettingsCatalog.screens.screenAreas)
    }

    /// An area menu's request: select its area, then open the
    /// popover on the editor that selection draws, a turn later.
    private func act(_ action: ScreenAreaAction) {
        switch action {
        case .select(let next):
            selection = next
            paneFocus = next
        case .rename(let area):
            selection = area
            DispatchQueue.main.async {
                renameRequest = AreaRenameRequest(
                    display: area.display,
                    area: area.area ?? 0
                )
            }
        case .adjust(let area):
            selection = area
            let display = model.displays.first { $0.id == area.display }
            guard let split = display.flatMap(model.areaSplit),
                let selected = area.area
            else { return }
            DispatchQueue.main.async {
                sizesRequest = AreaSizesRequest(
                    display: area.display,
                    area: selected,
                    seed: split
                )
            }
        }
    }

    /// `selection` kept on an area that exists: area 0 once its
    /// screen is split, none once it is whole again.
    private func normalized(
        _ selection: ScreenSelection?,
        rows: ScreensFamilyRows
    ) -> ScreenSelection? {
        guard let selection,
            let display = rows.displays.first(where: {
                $0.id == selection.display
            })
        else { return nil }
        guard let split = model.areaSplit(of: display) else {
            return ScreenSelection(display: display.id, area: nil)
        }
        let kept = split.areas.contains { $0.id == selection.area }
        return ScreenSelection(
            display: display.id,
            area: kept ? selection.area : 0
        )
    }

    private var placementUnavailable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                L(
                    "monitors.not_connected",
                    "Screens not connected"
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
