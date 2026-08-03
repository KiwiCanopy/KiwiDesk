import KiwiDeskCore
import SwiftUI

/// This Profile ▸ Gaps & Borders ▸ Focus border (#278). Sits
/// below Gaps and Drag & drop. Order per the settled design:
/// enable toggle → live two-window preview → unfocused toggle →
/// width → corner style (preview leads editor, AGENTS §2.7).
///
/// The two ring COLOURS left in #678 Phase 3 — every colour
/// KiwiDesk has now renders once, in Advanced Colours. What stays
/// is the ring's structure, and the unfocused toggle stays with
/// it: it decides whether a second ring is drawn at all, which is
/// this card's question, not a tint.
struct FocusBorderEditor: View {
    @ObservedObject var model: SettingsModel

    private var style: Binding<BorderStyle> {
        $model.config.settings.borderStyle
    }

    private var gates: GapsBordersGates {
        GapsBordersGates(settings: model.config.settings)
    }

    /// The block gate: the whole card is inert while the ring is
    /// off. Resolved once at the container so its grey and its
    /// sentence stay one decision (#678).
    private var blockReason: GapsBordersGates.InertReason? {
        gates.containerReason(for: .focusBorder)
    }

    private var blockHelp: String {
        blockReason.map(GapsBordersGateHelp.sentence) ?? ""
    }

    /// The glow-size row's gate, inside a live block: greyed while
    /// the glow effect is off.
    private var glowSizeReason: GapsBordersGates.InertReason? {
        gates.inertReason(for: .borders(.borderGlowSize))
    }

    var body: some View {
        // The header `?` is the gate's live anchor (#527): every
        // help affordance inside the greyed block is dead, so the
        // why-off explanation must live outside it.
        SettingsSection(
            SettingsCatalog.gapsAndBorders.focusBorder,
            caption: L(
                "border.caption",
                "Outlines the focused window so it stands out "
                    + "in a gapped layout."
            ),
            help: blockReason.map(GapsBordersGateHelp.sentence)
        ) {
            Toggle(
                L("border.enabled", "Show focus border"),
                isOn: style.enabled
            )
            FocusBorderPreview(style: style.wrappedValue)
            controls.modifier(
                GreyOut(active: blockReason != nil, help: blockHelp)
            )
        }
    }

    @ViewBuilder private var controls: some View {
        Toggle(
            L(
                "border.unfocused_enabled",
                "Show border on unfocused windows"
            ),
            isOn: style.unfocusedEnabled
        )
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
            ),
            // Glow off greys the group (resolver reason); with
            // glow on, `nil` hands greying back to the auto
            // sentinel, so auto-size still dims its own slider.
            gatedIsInert: glowSizeReason != nil ? true : nil,
            gatedHelp:
                glowSizeReason
                .map(GapsBordersGateHelp.sentence) ?? ""
        ) {
            PtSlider(
                label: L("border.glow_size", "Glow size"),
                value: style.glowSize,
                range: 1...20,
                autoAtZero: true
            )
        }
        Divider()
        FitGapsAction(model: model)
    }

    private var cornerLabel: String {
        L("border.corner_style", "Corners")
    }
}
