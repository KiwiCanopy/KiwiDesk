import KiwiDeskCore
import SwiftUI

/// Drag-and-drop visuals (#68 §3.14, restructured #231): the
/// shared corner radius up top (it styles both visuals, so it
/// belongs to neither column), then Ghost | Drop-zone as two
/// side-by-side columns. Each column leads with its own live
/// preview and puts its controls directly beneath, so tuning a
/// column's border width never scrolls its preview off-screen —
/// the whole reason the previews were split out of one shared
/// strip. Genuinely distinct runtime visuals users routinely
/// want different, edited by comparison, so twin columns state
/// the pairing once (the System-Settings Displays/Desktop
/// pattern). Static previews — no live drag (#123).
struct DragVisualsEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(
                SettingsCatalog.gapsAndBorders.dragCard,
                caption: L(
                    "drag.caption",
                    "Drag a window onto another to swap "
                        + "their positions in the layout."
                )
            ) {
                PtSlider(
                    label: L("drag.corner_radius", "Corner radius"),
                    value: $model.config.settings
                        .dragCornerRadius,
                    range: 0...40
                )
            }
            HStack(alignment: .top, spacing: 16) {
                column(
                    control: SettingsCatalog.gapsAndBorders.dragGhost,
                    caption: L(
                        "drag.ghost.caption",
                        "Marks the position your window is "
                            + "dragged from."
                    ),
                    visual: $model.config.settings.dragGhost
                )
                column(
                    control: SettingsCatalog.gapsAndBorders
                        .dragDropZone,
                    caption: L(
                        "drag.drop_zone.caption",
                        "Marks the position your window will "
                            + "snap into when dropped."
                    ),
                    visual: $model.config.settings.dragDropZone
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
        visual: Binding<DragVisual>
    ) -> some View {
        // The header `?` is the gate's live anchor (#527): with
        // the visual off the column below the Enabled toggle is
        // dimmed, and help inside a greyed block is dead.
        SettingsSection(
            control,
            caption: caption,
            subsection: true,
            help: visual.wrappedValue.enabled
                ? nil
                : L(
                    "drag.disabled.help",
                    "Turn on Enabled to edit this visual."
                )
        ) {
            DragVisualPreview(
                visual: visual.wrappedValue,
                cornerRadius: model.config.settings
                    .dragCornerRadius
            )
            DragVisualControls(visual: visual)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(
            \.settingsLabelColumn,
            SettingsMetrics.dragColumnLabelColumn
        )
    }
}

/// The border + fill controls shared by ghost and drop zone.
/// Rows are relabeled to their in-group short forms ("Width",
/// "Alignment") since the Border/Fill sub-grouping already
/// carries the prefix (#231). All rows read the narrowed Drag
/// label axis from the environment. The two COLOUR rows left in
/// #678 Phase 3 — Border and Fill still decide whether each part
/// is drawn, which is this column's question; what it is painted
/// with is Advanced Colours'.
struct DragVisualControls: View {
    @Binding var visual: DragVisual

    /// Two gates the column already implies and none of it
    /// enforced (#520): with the visual off nothing it draws
    /// exists, and with Border off its width and alignment shape
    /// nothing. The column's preview already prints "disabled"
    /// beside them, so the controls were the only surface still
    /// claiming to matter. Greyed, never hidden (#171).
    ///
    /// Each inner gate carries `visual.enabled &&` so nested
    /// `GreyOut`s can't multiply their 0.5 opacity to 0.25 —
    /// the outer gate already covers the visual-off case.
    var body: some View {
        Toggle(L("drag.enabled", "Enabled"), isOn: $visual.enabled)
        Divider()
        Group {
            Toggle(
                L("drag.border", "Border"),
                isOn: $visual.border
            )
            Group {
                PtSlider(
                    label: L("drag.border_width", "Width"),
                    value: $visual.borderWidth,
                    range: 0...20
                )
                SegmentedPicker(
                    borderAlignmentLabel,
                    selection: $visual.borderAlignment,
                    options: [
                        (L("drag.inside", "Inside"), .inside),
                        (L("drag.outside", "Outside"), .outside),
                    ]
                )
            }
            .modifier(
                GreyOut(
                    active: !visual.border,
                    help: borderOffHelp
                )
            )
            Divider()
            Toggle(L("drag.fill", "Fill"), isOn: $visual.fill)
        }
        .modifier(
            GreyOut(
                active: !visual.enabled,
                help: L(
                    "drag.disabled.help",
                    "Turn on Enabled to edit this visual."
                )
            )
        )
    }

    private var borderOffHelp: String {
        L(
            "drag.border.off_help",
            "Turn on Border to edit its width and "
                + "alignment."
        )
    }

    private var borderAlignmentLabel: String {
        L("drag.border_alignment", "Alignment")
    }
}
