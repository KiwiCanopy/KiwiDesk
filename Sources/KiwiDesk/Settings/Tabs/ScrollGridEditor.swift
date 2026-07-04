import KiwiDeskCore
import SwiftUI

/// Scrolling and Grid tuning (05_GUI_Concept §2, Tab 3).
struct ScrollGridEditor: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            scrolling
            grid
        }
    }

    private var widthLabel: String {
        let width = Int(
            model.config.settings.scrolling.windowWidth
        )
        return "\(width) pt"
    }

    private var scrolling: some View {
        SettingsSection("Scrolling") {
            HStack {
                Text("Column width")
                    .frame(width: 110, alignment: .leading)
                Slider(
                    value: $model.config.settings.scrolling
                        .windowWidth,
                    in: 100...2000,
                    step: 10
                )
                Text(widthLabel)
                    .frame(width: 64, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
            Picker(
                "Focused anchor",
                selection: $model.config.settings.scrolling
                    .anchor
            ) {
                Text("Center").tag(ScrollingParams.Anchor.center)
                Text("Left").tag(ScrollingParams.Anchor.left)
                Text("Right").tag(ScrollingParams.Anchor.right)
            }
            .pickerStyle(.segmented)
            PlacementPicker(
                placement: $model.config.settings.scrolling
                    .newWindowPlacement
            )
        }
    }

    private var grid: some View {
        SettingsSection("Grid") {
            Picker(
                "Grid type",
                selection: $model.config.settings.grid.type
            ) {
                Text("Dynamic").tag(GridParams.GridType.dynamic)
                Text("Rigid").tag(GridParams.GridType.rigid)
            }
            .pickerStyle(.segmented)
            Toggle(
                "Fill empty space",
                isOn: $model.config.settings.grid.fillEmptySpace
            )
            Picker(
                "Split direction",
                selection: $model.config.settings.grid
                    .splitDirection
            ) {
                Text("Horizontal")
                    .tag(GridParams.SplitDirection.horizontal)
                Text("Vertical")
                    .tag(GridParams.SplitDirection.vertical)
            }
            .pickerStyle(.segmented)
            Stepper(
                "Columns: "
                    + "\(model.config.settings.grid.columns)",
                value: $model.config.settings.grid.columns,
                in: 1...10
            )
            Stepper(
                "Rows: \(model.config.settings.grid.rows)",
                value: $model.config.settings.grid.rows,
                in: 1...10
            )
            PlacementPicker(
                placement: $model.config.settings.grid
                    .newWindowPlacement
            )
        }
    }
}
