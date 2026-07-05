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

    /// The scroll axis runs top↔bottom when vertical, so the slot
    /// size reads as a row *height*, and the anchor ends as
    /// top/bottom — labels swap accordingly (frontend only; the
    /// stored `slot_size` / anchor enum are orientation-neutral).
    private var isVertical: Bool {
        model.config.settings.scrolling.orientation == .vertical
    }

    private var sizeLabel: String {
        isVertical ? "Row height" : "Column width"
    }

    private enum SizeUnit: Hashable { case auto, points, percent }

    private var sizeUnit: SizeUnit {
        switch model.config.settings.scrolling.slotSize {
        case .auto: return .auto
        case .points: return .points
        case .fraction: return .percent
        }
    }

    /// Seed value for the Points unit: keep an explicit pt, else
    /// fall back to the orientation standard `auto` would resolve.
    private var currentPoints: CGFloat {
        if case .points(let points) =
            model.config.settings.scrolling.slotSize
        {
            return points
        }
        return isVertical
            ? ScrollSize.autoVertical : ScrollSize.autoHorizontal
    }

    private var currentFraction: Double {
        if case .fraction(let fraction) =
            model.config.settings.scrolling.slotSize
        {
            return fraction
        }
        return 0.5
    }

    private var sizeUnitBinding: Binding<SizeUnit> {
        Binding(
            get: { sizeUnit },
            set: { unit in
                switch unit {
                case .auto:
                    model.config.settings.scrolling.slotSize = .auto
                case .points:
                    model.config.settings.scrolling.slotSize =
                        .points(currentPoints)
                case .percent:
                    model.config.settings.scrolling.slotSize =
                        .fraction(currentFraction)
                }
            }
        )
    }

    private var pointsBinding: Binding<Double> {
        Binding(
            get: { Double(currentPoints) },
            set: {
                model.config.settings.scrolling.slotSize =
                    .points(CGFloat($0))
            }
        )
    }

    private var percentBinding: Binding<Double> {
        Binding(
            get: { currentFraction * 100 },
            set: {
                model.config.settings.scrolling.slotSize =
                    .fraction($0 / 100)
            }
        )
    }

    private var scrolling: some View {
        SettingsSection("Scrolling") {
            Picker("Size unit", selection: sizeUnitBinding) {
                Text("Auto").tag(SizeUnit.auto)
                Text("Points").tag(SizeUnit.points)
                Text("Percent").tag(SizeUnit.percent)
            }
            .pickerStyle(.segmented)
            sizeControl
            Picker(
                "Focused anchor",
                selection: $model.config.settings.scrolling
                    .anchor
            ) {
                Text("Center").tag(ScrollingParams.Anchor.center)
                Text(isVertical ? "Top" : "Left")
                    .tag(ScrollingParams.Anchor.left)
                Text(isVertical ? "Bottom" : "Right")
                    .tag(ScrollingParams.Anchor.right)
            }
            .pickerStyle(.segmented)
            Picker(
                "Scroll orientation",
                selection: $model.config.settings.scrolling
                    .orientation
            ) {
                Text("Horizontal")
                    .tag(ScrollingParams.Orientation.horizontal)
                Text("Vertical")
                    .tag(ScrollingParams.Orientation.vertical)
            }
            .pickerStyle(.segmented)
            PlacementPicker(
                placement: $model.config.settings.scrolling
                    .newWindowPlacement
            )
        }
    }

    @ViewBuilder
    private var sizeControl: some View {
        switch sizeUnit {
        case .auto:
            HStack {
                Text(sizeLabel)
                    .frame(width: 110, alignment: .leading)
                Text("Auto — orientation standard")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        case .points:
            HStack {
                Text(sizeLabel)
                    .frame(width: 110, alignment: .leading)
                Slider(value: pointsBinding, in: 100...2000, step: 10)
                Text("\(Int(currentPoints)) pt")
                    .frame(width: 64, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
        case .percent:
            HStack {
                Text(sizeLabel)
                    .frame(width: 110, alignment: .leading)
                Slider(value: percentBinding, in: 5...100, step: 5)
                Text("\(Int(currentFraction * 100)) %")
                    .frame(width: 64, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
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
