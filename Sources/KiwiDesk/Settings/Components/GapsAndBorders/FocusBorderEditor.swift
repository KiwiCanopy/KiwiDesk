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
