import KiwiDeskCore
import SwiftUI

/// Monocle orientation and indicator-bar tuning; the bar colors
/// live in `MonocleColorsEditor` (05_GUI_Concept §2, Tab 3).
struct MonocleEditor: View {
    @ObservedObject var model: SettingsModel

    private var bar: Binding<MonocleBarParams> {
        $model.config.settings.monocle.bar
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection("Monocle") {
                Picker(
                    "Focus orientation",
                    selection: $model.config.settings.monocle
                        .orientation
                ) {
                    Text("Horizontal")
                        .tag(MonocleParams.Orientation.horizontal)
                    Text("Vertical")
                        .tag(MonocleParams.Orientation.vertical)
                }
                .pickerStyle(.segmented)
            }
            SettingsSection("Indicator bar") {
                Toggle("Show bar", isOn: bar.enabled)
                behavior
                appearance
            }
            MonocleColorsEditor(bar: bar)
        }
    }

    @ViewBuilder private var behavior: some View {
        Picker("Position", selection: bar.position) {
            Text("Top").tag(MonocleBarParams.Position.top)
            Text("Bottom").tag(MonocleBarParams.Position.bottom)
            Text("Left").tag(MonocleBarParams.Position.left)
            Text("Right").tag(MonocleBarParams.Position.right)
        }
        Picker("Style", selection: bar.style) {
            Text("Pills").tag(MonocleBarParams.Style.pills)
            Text("Segments")
                .tag(MonocleBarParams.Style.segments)
            Text("Underline")
                .tag(MonocleBarParams.Style.underline)
        }
        Picker("Active item", selection: bar.activeStyle) {
            Text("Highlight")
                .tag(MonocleBarParams.ActiveStyle.highlight)
            Text("Gap").tag(MonocleBarParams.ActiveStyle.gap)
        }
        Picker("Content", selection: bar.content) {
            Text("Icon").tag(MonocleBarParams.Content.icon)
            Text("Name").tag(MonocleBarParams.Content.name)
            Text("Icon & name")
                .tag(MonocleBarParams.Content.iconAndName)
        }
        Toggle(
            "Group adjacent same-app windows",
            isOn: bar.groupAdjacentWindows
        )
    }

    @ViewBuilder private var appearance: some View {
        PtSlider(
            label: "Thickness",
            value: bar.thickness,
            range: 8...80
        )
        PtSlider(
            label: "Item size",
            value: bar.itemSize,
            range: 0...200
        )
        PtSlider(
            label: "Item gap",
            value: bar.itemGap,
            range: 0...40
        )
        PtSlider(
            label: "Font size",
            value: bar.fontSize,
            range: 0...32
        )
        PtSlider(
            label: "Corner radius",
            value: bar.cornerRadius,
            range: 0...40
        )
    }
}
