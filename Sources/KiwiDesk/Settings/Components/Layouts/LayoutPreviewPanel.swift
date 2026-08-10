import KiwiDeskCore
import SwiftUI

/// The live preview under a layout's rows (turn 10): the
/// selected layout's schematic at pane width, with the window
/// count as a slider the reader drives.
///
/// The count is what turns a picture of a layout into a
/// simulation of one. Cascade overflow and Cascade all draw the
/// same frame until the stack is deep enough to overflow; a
/// track limit means nothing until there are more windows than
/// tracks; a dynamic grid's balance is invisible at a fixed
/// count. Every one of those becomes a drag of this slider.
///
/// The count is view state, deliberately: it is a question the
/// reader is asking of the preview, not a setting, so it neither
/// persists nor reaches the config — and it resets per visit,
/// which is the right default for a question.
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
            // Read-only, so it watches from the panel beside
            // the rows rather than sitting among them (owner
            // 2026-08-10).
            SpacesUsingLayout(model: model, mode: mode)
        }
    }

    /// Hoisted out of the `SettingsSlider` call, which already
    /// carries a closure-pair `Binding`: a range built inline
    /// beside it is the type-checker-budget shape gui.md names.
    private var countRange: ClosedRange<Double> {
        let band = LayoutSchematic.windowCountRange
        return Double(band.lowerBound)...Double(band.upperBound)
    }

    /// Label and readout hug their text instead of taking the
    /// content pane's 210 pt label column: this row lives in
    /// the 392 pt PANEL now, where that column left the track
    /// a knob's width of room (owner caught it on screen,
    /// 2026-08-10) — the slider is the row's point, so it gets
    /// the flexible middle.
    private var countRow: some View {
        HStack(spacing: 10) {
            // "Window count", not a bare "Windows": beside a
            // slider and a numeric readout the short form is
            // unambiguous on screen, but a translator reading the
            // key alone cannot tell it from the OS's own name for
            // a window.
            Text(
                L(
                    "layout_defaults.preview_windows",
                    "Window count"
                )
            )
            .fixedSize()
            SettingsSlider(
                value: Binding(
                    get: { Double(windows) },
                    set: { windows = Int($0.rounded()) }
                ),
                range: countRange,
                step: 1
            )
            .frame(maxWidth: .infinity)
            Text("\(windows)")
                .frame(minWidth: 24, alignment: .trailing)
                .foregroundStyle(.secondary)
                .font(.body.monospacedDigit())
        }
    }
}
