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
                SettingsCatalog.appearance.dragCard,
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
                    control: SettingsCatalog.appearance.dragGhost,
                    caption: L(
                        "drag.ghost.caption",
                        "Marks the position your window is "
                            + "dragged from."
                    ),
                    visual: $model.config.settings.dragGhost
                )
                column(
                    control: SettingsCatalog.appearance
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

/// One mock window rect rendered with the current visual's
/// fill, border, and the shared corner radius.
private struct DragVisualPreview: View {
    let visual: DragVisual
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            // A neutral desktop backdrop so translucent
            // fills read realistically.
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            mock
                .padding(10)
            if !visual.enabled {
                Text(L("drag.disabled", "disabled"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 84)
        .frame(maxWidth: .infinity)
    }

    private var mock: some View {
        // Remap the full slider ranges onto the preview's
        // smaller span (the AppBarPreviewStrip / GapPreviewScale
        // fix, #231): a hard cap made both sliders visibly stop
        // responding halfway up, reading as "the setting broke."
        let radius = scale(cornerRadius, from: 0...40, to: 0...20)
        let width = scale(
            visual.borderWidth,
            from: 0...20,
            to: 0...10
        )
        return RoundedRectangle(cornerRadius: radius)
            .fill(
                visual.fill
                    ? Color(kiwiHex: visual.fillColor) : .clear
            )
            .overlay { border(radius: radius, width: width) }
            .opacity(visual.enabled ? 1 : 0.25)
    }

    /// Illustrate the footprint each alignment gives at runtime
    /// (`DragOverlay.adjustedFrame`, #231): inset within the
    /// tile for `.inside`, sitting outside the tile edge for
    /// `.outside`. Schematic, not pixel-exact — the point is the
    /// larger outward footprint, sized to half the (scaled)
    /// width the slider drives so the difference grows with the
    /// same number the user is dragging.
    @ViewBuilder private func border(
        radius: CGFloat,
        width: CGFloat
    ) -> some View {
        if visual.border {
            let color = Color(kiwiHex: visual.borderColor)
            switch visual.borderAlignment {
            case .inside:
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(color, lineWidth: width)
            case .outside:
                // Grow the corner radius with the outward offset
                // (a parallel offset of a rounded rect by d has
                // radius R + d) so the border's inner corner
                // stays flush with the tile's rounded corner —
                // keeping `radius` here left a backdrop sliver in
                // each corner.
                RoundedRectangle(cornerRadius: radius + width / 2)
                    .stroke(color, lineWidth: width)
                    .padding(-width / 2)
            }
        }
    }

    /// Linear map of `value` from one closed range onto another,
    /// clamped to the target range at the ends (mirrors
    /// `AppBarPreviewStrip.scale`).
    private func scale(
        _ value: CGFloat,
        from src: ClosedRange<CGFloat>,
        to dst: ClosedRange<CGFloat>
    ) -> CGFloat {
        let span = src.upperBound - src.lowerBound
        guard span > 0 else { return dst.lowerBound }
        let t = min(max((value - src.lowerBound) / span, 0), 1)
        return dst.lowerBound
            + t * (dst.upperBound - dst.lowerBound)
    }
}

/// The border + fill controls shared by ghost and drop zone.
/// Rows are relabeled to their in-group short forms ("Color",
/// "Width", "Alignment") since the Border/Fill sub-grouping
/// already carries the prefix (#231); VoiceOver keeps the full
/// name via `a11yLabel`. All rows read the narrowed Drag label
/// axis from the environment.
struct DragVisualControls: View {
    @Binding var visual: DragVisual
    @Environment(\.settingsLabelColumn) private var labelColumn

    /// Three gates the column already implies and none of it
    /// enforced (#520): with the visual off nothing it draws
    /// exists, and with Border or Fill off their own rows tint
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
                HexColorField(
                    label: L("drag.border_color", "Color"),
                    a11yLabel: L(
                        "drag.border_color.a11y",
                        "Border color"
                    ),
                    labelWidth: labelColumn,
                    hex: $visual.borderColor
                )
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
            HexColorField(
                label: L("drag.fill_color", "Color"),
                a11yLabel: L(
                    "drag.fill_color.a11y",
                    "Fill color"
                ),
                labelWidth: labelColumn,
                hex: $visual.fillColor
            )
            .modifier(
                GreyOut(
                    active: !visual.fill,
                    help: fillOffHelp
                )
            )
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
            "Turn on Border to edit its color, width, and "
                + "alignment."
        )
    }

    private var fillOffHelp: String {
        L("drag.fill.off_help", "Turn on Fill to edit its color.")
    }

    private var borderAlignmentLabel: String {
        L("drag.border_alignment", "Alignment")
    }
}
