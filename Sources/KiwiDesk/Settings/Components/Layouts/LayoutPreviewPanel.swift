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
    }

    private var countRow: some View {
        HStack {
            Text(L("layout_defaults.preview_windows", "Windows"))
                .frame(
                    width: SettingsMetrics.labelColumn,
                    alignment: .leading
                )
            SettingsSlider(
                value: Binding(
                    get: { Double(windows) },
                    set: { windows = Int($0.rounded()) }
                ),
                range: Double(
                    LayoutSchematic.windowCountRange.lowerBound
                )...Double(
                    LayoutSchematic.windowCountRange.upperBound
                ),
                step: 1
            )
            Text("\(windows)")
                .frame(
                    width: SettingsMetrics.readoutColumn,
                    alignment: .trailing
                )
                .foregroundStyle(.secondary)
                .font(.body.monospacedDigit())
        }
    }
}
