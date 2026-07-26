import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Appearance ▸ Focus border (#278). Sits below
/// Gaps and Drag & drop. Order per the settled design: enable
/// toggle → live two-window preview → focused color → unfocused
/// toggle + color → width → corner style (preview leads editor,
/// AGENTS §2.7). Colors use the shared hex swatch — the same
/// control and format as the App Bar and drag colors.
struct FocusBorderEditor: View {
    @ObservedObject var model: SettingsModel

    private var style: Binding<BorderStyle> {
        $model.config.settings.borderStyle
    }

    var body: some View {
        // The header `?` is the gate's live anchor (#527): every
        // help affordance inside the greyed block is dead, so the
        // why-off explanation must live outside it.
        SettingsSection(
            L("border.title", "Focus border"),
            caption: L(
                "border.caption",
                "Outlines the focused window so it stands out "
                    + "in a gapped layout."
            ),
            help: style.wrappedValue.enabled ? nil : offHelp
        ) {
            Toggle(
                L("border.enabled", "Show focus border"),
                isOn: style.enabled
            )
            FocusBorderPreview(style: style.wrappedValue)
            controls.modifier(
                GreyOut(
                    active: !style.wrappedValue.enabled,
                    help: offHelp
                )
            )
        }
    }

    private var offHelp: String {
        L(
            "border.controls.disabled",
            "Turn on Show focus border to edit "
                + "these settings."
        )
    }

    @ViewBuilder private var controls: some View {
        HexColorField(
            label: L("border.focused_color", "Color"),
            a11yLabel: L(
                "border.focused_color.a11y",
                "Focused window border color"
            ),
            hex: style.focusedColor
        )
        Divider()
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                L(
                    "border.unfocused_enabled",
                    "Show border on unfocused windows"
                ),
                isOn: style.unfocusedEnabled
            )
            HexColorField(
                label: L("border.unfocused_color", "Color"),
                a11yLabel: L(
                    "border.unfocused_color.a11y",
                    "Unfocused window border color"
                ),
                hex: style.unfocusedColor
            )
            .modifier(
                // Its gating toggle sits directly above, so the
                // adjacency is the anchor (#527) — the hover
                // string just names the action.
                GreyOut(
                    active: !style.wrappedValue.unfocusedEnabled,
                    help: L(
                        "border.unfocused_color.disabled",
                        "Turn on Show border on unfocused "
                            + "windows to edit its color."
                    )
                )
            )
        }
        Divider()
        PtSlider(
            label: L("border.width", "Width"),
            value: style.width,
            range: 1...20
        )
        SegmentedPicker(
            cornerLabel,
            selection: style.cornerStyle,
            options: [
                (L("border.corner.rounded", "Rounded"), .rounded),
                (L("border.corner.square", "Square"), .square),
            ]
        )
        // A render trait of the ring like Width and Corners — a soft
        // bloom in the focused ring's hue (#358). Sits with the other
        // styling traits, no caption (the live preview above shows
        // it on toggle); a11y gets the descriptive gloss. A noun
        // phrase like its true siblings (Width, Corners), NOT the
        // "Show X" family — that family gates an element other
        // controls configure, while this toggles a trait; and the
        // verb form was ambiguous in German ("Leuchten anzeigen"
        // reads as "show lamps"). ui-designer verdict 2026-07-26.
        Toggle(
            L("border.glow", "Glow effect"),
            isOn: style.glow
        )
        .accessibilityLabel(
            L(
                "border.glow.a11y",
                "Soft glow around the focus border"
            )
        )
        // Directly below the toggle that gates it (topic
        // grouping); Auto is the width-scaled formula's 0
        // sentinel, the AutoSentinel face (#551). The `enabled &&`
        // conjunction is NOT about dim-compounding (the
        // isInsideGreyOut flag already prevents that) — it keeps
        // this gate inactive while the whole block is off, so
        // its "Turn on Glow effect" hover can't shadow the
        // block-level "Turn on Show focus border" explanation.
        AutoGatedGroup(
            title: L("border.glow_size.auto", "Auto glow size"),
            isOn: AutoSentinel.binding(
                style.glowSize,
                // Take over from where auto left off — a fixed
                // restore snapped the ring visibly at non-default
                // widths (auto reaches 12 at width 20). Always
                // inside the 1-20 GUI band (the formula caps
                // at 12).
                restore: BorderStyle.glowBlur(
                    for: style.wrappedValue.clampedWidth
                ).rounded()
            )
        ) {
            PtSlider(
                label: L("border.glow_size", "Glow size"),
                value: style.glowSize,
                range: 1...20,
                autoAtZero: true
            )
        }
        .modifier(
            GreyOut(
                active: style.wrappedValue.enabled
                    && !style.wrappedValue.glow,
                help: L(
                    "border.glow_size.disabled",
                    "Turn on Glow effect to adjust its size."
                )
            )
        )
        Divider()
        FitGapsAction(model: model)
    }

    private var cornerLabel: String {
        L("border.corner_style", "Corners")
    }
}

/// Two mock windows on a neutral desktop: the focused one always
/// ringed, the other ringed only when unfocused borders are on.
/// Reflects width and corner style live so the editor's controls
/// preview before they hit real windows.
private struct FocusBorderPreview: View {
    let style: BorderStyle

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            HStack(spacing: 16) {
                window(
                    color: style.focusedColor,
                    ringed: true,
                    // Glow is focused-ring-only (#358).
                    glow: style.glow
                )
                window(
                    color: style.unfocusedColor,
                    ringed: style.unfocusedEnabled,
                    glow: false
                )
            }
            .padding(14)
        }
        .frame(height: 96)
        .frame(maxWidth: .infinity)
        .opacity(style.enabled ? 1 : 0.4)
    }

    private func window(
        color: String,
        ringed: Bool,
        glow: Bool
    ) -> some View {
        // Remap the 1–20 pt width onto the preview's smaller span
        // so a thick border reads without swamping the mock.
        let width = scale(
            style.clampedWidth,
            from: 1...20,
            to: 1...7
        )
        // Remap the RESOLVED glow blur (auto formula or the
        // explicit glow_size, #533/#551) the same way — the
        // literal pt value would swamp this 96 pt mock and
        // read as a smear, not a halo (#358). A proportional
        // approximation, like width and corners here.
        // The source band is derived from the formula's own
        // clamp, so a retuned floor/cap cannot leave this remap
        // silently stale (the numbers live in
        // `BorderGeometryTests`, nowhere else); an explicit
        // size past the band clamps at the mock's top, which
        // is honest enough for a schematic.
        let glowRadius = scale(
            style.resolvedGlowBlur,
            from: BorderStyle.glowBlur(
                for: BorderStyle.minWidth
            )...BorderStyle.glowBlur(for: BorderStyle.maxWidth),
            to: 1...5
        )
        let radius: CGFloat =
            style.cornerStyle == .square ? 0 : 12
        return RoundedRectangle(cornerRadius: radius)
            .fill(Color.secondary.opacity(0.25))
            .overlay {
                if ringed {
                    // Preview the configured visible width. The real
                    // renderer adds a hidden overlap behind the
                    // window, which does not change this weight.
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(
                            Color(kiwiHex: color),
                            lineWidth: width
                        )
                        .shadow(
                            // Bloom uses the brightened derivative,
                            // matching the real renderer (#358).
                            color: glow
                                ? Color(
                                    kiwiHex: BorderStyle.glowColor(
                                        from: color
                                    )
                                )
                                : .clear,
                            radius: glow ? glowRadius : 0
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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
