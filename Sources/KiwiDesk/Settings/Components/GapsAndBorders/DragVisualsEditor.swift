import KiwiDeskCore
import SwiftUI

/// Drag-and-drop visuals (#68 §3.14, restructured #231, #754):
/// Ghost | Drop-zone as two side-by-side columns inside the
/// Drag & drop card. Each column leads with its own live
/// preview and puts its controls directly beneath, so tuning a
/// column's border width never scrolls its preview off-screen —
/// the whole reason the previews were split out of one shared
/// strip. Genuinely distinct runtime visuals users routinely
/// want different, edited by comparison, so twin columns state
/// the pairing once (the System-Settings Displays/Desktop
/// pattern). Static previews — no live drag (#123).
///
/// The shared corner radius left for the Borders card in #754,
/// where it also drives the ring; the two alignment pickers left
/// the GUI entirely there (GUI_REMOVED_2026-08).
struct DragVisualsEditor: View {
    @ObservedObject var model: SettingsModel

    private var gates: GapsBordersGates {
        GapsBordersGates(
            settings: model.config.settings,
            linkedWidth: model.borderWidthLinked
        )
    }

    var body: some View {
        SettingsSection(
            SettingsCatalog.gapsAndBorders.dragCard,
            caption: L(
                "drag.caption",
                "Drag a window onto another to swap "
                    + "their positions in the layout."
            )
        ) {
            HStack(alignment: .top, spacing: 16) {
                column(
                    control: SettingsCatalog.gapsAndBorders.dragGhost,
                    caption: L(
                        "drag.ghost.caption",
                        "Marks the position your window is "
                            + "dragged from."
                    ),
                    visual: $model.config.settings.dragGhost,
                    enabledReason: gates.inertReason(
                        for: .borders(.dragGhostBorder)
                    ),
                    borderReason: gates.inertReason(
                        for: .borders(.dragGhostBorderWidth)
                    )
                )
                column(
                    control: SettingsCatalog.gapsAndBorders
                        .dragDropZone,
                    caption: L(
                        "drag.drop_zone.caption",
                        "Marks the position your window will "
                            + "snap into when dropped."
                    ),
                    visual: $model.config.settings.dragDropZone,
                    enabledReason: gates.inertReason(
                        for: .borders(.dragDropZoneBorder)
                    ),
                    borderReason: gates.inertReason(
                        for: .borders(.dragDropZoneBorderWidth)
                    )
                )
            }
        }
    }

    /// One self-contained column: preview leads, its controls
    /// below, on the narrowed Drag label axis (#231) so the
    /// half-width slider keeps real travel.
    private func column(
        control: SettingsControl,
        caption: String,
        visual: Binding<DragVisual>,
        enabledReason: GapsBordersGates.InertReason?,
        borderReason: GapsBordersGates.InertReason?
    ) -> some View {
        // The header `?` is the gate's live anchor (#527): with
        // the visual off the column below the Enabled toggle is
        // dimmed, and help inside a greyed block is dead.
        SettingsSection(
            control,
            caption: caption,
            subsection: true,
            help: enabledReason.map(GapsBordersGateHelp.sentence)
        ) {
            DragVisualPreview(
                visual: visual.wrappedValue,
                cornerRadius: model.config.settings
                    .dragCornerRadius
            )
            DragVisualControls(
                visual: visual,
                enabledReason: enabledReason,
                borderReason: borderReason
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(
            \.settingsLabelColumn,
            SettingsMetrics.dragColumnLabelColumn
        )
    }
}

/// The border + fill controls shared by ghost and drop zone.
/// The width row is relabeled to its in-group short form
/// ("Width") since the Border/Fill sub-grouping already carries
/// the prefix (#231). All rows read the narrowed Drag label axis
/// from the environment. The two COLOUR rows left in #678
/// Phase 3 — Border and Fill still decide whether each part
/// is drawn, which is this column's question; what it is painted
/// with is Advanced Colours'.
struct DragVisualControls: View {
    @Binding var visual: DragVisual
    let enabledReason: GapsBordersGates.InertReason?
    let borderReason: GapsBordersGates.InertReason?

    /// Three gates the column implies and none of it enforced
    /// (#520, #754): with the visual off nothing it draws
    /// exists, with Border off its width shapes nothing, and
    /// with the one-width link on the Borders card's master owns
    /// that width. The column's preview already prints
    /// "disabled" beside the first, so the controls were the
    /// only surface still claiming to matter. Greyed, never
    /// hidden (#171).
    ///
    /// The one remaining inner gate needs no `visual.enabled &&`
    /// conjunction: `GreyOut` dims once however deeply it nests
    /// (`AutoGatedGroup`), and the colour rows that used to make
    /// the hover-string shadowing matter here have moved to
    /// Advanced Colours.
    var body: some View {
        Toggle(L("drag.enabled", "Enabled"), isOn: $visual.enabled)
        Divider()
        Group {
            Toggle(
                L("drag.border", "Border"),
                isOn: $visual.border
            )
            PtSlider(
                label: L("drag.border_width", "Width"),
                value: $visual.borderWidth,
                range: 0...20
            )
            .modifier(
                GreyOut(
                    active: borderReason != nil,
                    help:
                        borderReason
                        .map(GapsBordersGateHelp.sentence) ?? ""
                )
            )
            Divider()
            Toggle(L("drag.fill", "Fill"), isOn: $visual.fill)
        }
        .modifier(
            GreyOut(
                active: enabledReason != nil,
                help:
                    enabledReason
                    .map(GapsBordersGateHelp.sentence) ?? ""
            )
        )
    }
}
