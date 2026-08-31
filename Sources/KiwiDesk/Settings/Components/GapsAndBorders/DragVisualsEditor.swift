import KiwiDeskCore
import SwiftUI

/// Drag-and-drop visuals editor card for ghost and drop zone
/// settings (`GapsBordersGates`, #68 §3.14, #231, #754). Twin
/// columns, each preview above its own controls; static previews
/// — no live drag (#123). The colour rows left for Advanced
/// Colours in #678 Phase 3; what stays is what only a column can
/// answer.
struct DragVisualsEditor: View {
    @ObservedObject var model: SettingsModel

    private var gates: GapsBordersGates {
        GapsBordersGates(settings: model.config.settings)
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
                    )
                )
            }
        }
    }

    /// Renders individual column with gated controls (#527).
    private func column(
        control: SettingsControl,
        caption: String,
        visual: Binding<DragVisual>,
        enabledReason: GapsBordersGates.InertReason?
    ) -> some View {
        // The header `?` is the gate's live anchor (#527): with
        // the visual off the column below is dimmed, and help
        // inside a greyed block is dead.
        SettingsSection(
            control,
            caption: caption,
            subsection: true,
            help: enabledReason.map(GapsBordersGateHelp.sentence)
        ) {
            DragVisualControls(
                visual: visual,
                enabledReason: enabledReason
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Border and fill toggle switches for drag ghost and drop zone
/// (`GreyOut`, #171, #520, #754).
struct DragVisualControls: View {
    @Binding var visual: DragVisual
    let enabledReason: GapsBordersGates.InertReason?

    var body: some View {
        Toggle(L("drag.enabled", "Enabled"), isOn: $visual.enabled)
        Divider()
        Group {
            Toggle(
                L("drag.border", "Border"),
                isOn: $visual.border
            )
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
