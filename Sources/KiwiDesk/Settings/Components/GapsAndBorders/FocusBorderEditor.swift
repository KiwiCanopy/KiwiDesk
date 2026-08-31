import KiwiDeskCore
import SwiftUI

/// Editor view for focus border settings (#278, #678 Phase 3, #754).
struct FocusBorderEditor: View {
    @ObservedObject var model: SettingsModel

    private var style: Binding<BorderStyle> {
        $model.config.settings.borderStyle
    }

    private var gates: GapsBordersGates {
        GapsBordersGates(settings: model.config.settings)
    }

    /// Block gate for entire card when focus border is disabled (#678).
    private var blockReason: GapsBordersGates.InertReason? {
        gates.containerReason(for: .focusBorder)
    }

    private var blockHelp: String {
        blockReason.map(GapsBordersGateHelp.sentence) ?? ""
    }

    /// Glow size row gate when glow effect is disabled.
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
        // A noun phrase like its true siblings (Width, Corners),
        // NOT the "Show X" family — that family gates an element,
        // this toggles a trait (#358); and the verb form was
        // ambiguous in German ("Leuchten anzeigen" reads as "show
        // lamps"). ui-designer verdict 2026-07-26.
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
        AutoGatedGroup(
            title: L("border.glow_size.auto", "Auto glow size"),
            isOn: AutoSentinel.binding(
                style.glowSize,
                // Auto is the width-scaled formula's 0 sentinel
                // (#551); take over from where auto left off — a
                // fixed restore snapped the ring visibly at
                // non-default widths.
                restore: BorderStyle.glowBlur(
                    for: style.wrappedValue.clampedWidth
                ).rounded()
            ),
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
}
