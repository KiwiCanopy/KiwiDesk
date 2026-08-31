import KiwiDeskCore
import SwiftUI

/// Live interactive preview panel for layout mode defaults (#678).
struct LayoutPreviewPanel: View {
    @ObservedObject var model: SettingsModel
    let mode: LayoutMode
    @State private var windows = LayoutSchematic.defaultWindowCount

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSection(
                SettingsCatalog.layoutDefaults.livePreview
            ) {
                LayoutSchematicView(
                    mode: mode,
                    settings: model.config.settings,
                    windows: windows,
                    scale: .panel
                )
                countRow
            }
            SpacesUsingLayout(model: model, mode: mode)
        }
    }

    /// Hoisted slider range (`LayoutSchematic.windowCountRange`, `gui.md`).
    private var countRange: ClosedRange<Double> {
        let band = LayoutSchematic.windowCountRange
        return Double(band.lowerBound)...Double(band.upperBound)
    }

    private var countRow: some View {
        HStack(spacing: 10) {
            Text(
                L(
                    "layout_defaults.preview_windows",
                    "Window count"
                )
            )
            .fixedSize()
            // Drawn, not spoken: it names the slider below, and
            // the slider says the name itself (code review
            // 2026-08-11 — the ruling `SettingsRowLabel` applies
            // at its seam).
            .accessibilityHidden(true)
            SettingsSlider(
                value: Binding(
                    get: { Double(windows) },
                    set: { windows = Int($0.rounded()) }
                ),
                range: countRange,
                step: 1,
                // A sibling `Text` names nothing for VoiceOver,
                // so the slider announced a bare percentage
                // (#678 turn 20a rule 2). Naming and valuing the
                // control puts both on the thing adjusted — the
                // seam every slider takes (#812).
                label: L(
                    "layout_defaults.preview_windows",
                    "Window count"
                ),
                spokenValue: "\(windows)"
            )
            .frame(maxWidth: .infinity)
            Text("\(windows)")
                .frame(minWidth: 24, alignment: .trailing)
                .foregroundStyle(SettingsTheme.ink2)
                .font(.body.monospacedDigit())
                .settingsReadout()
        }
    }
}
