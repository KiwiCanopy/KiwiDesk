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

    /// Seed for the Points unit: keep an explicit pt, else a
    /// sensible per-axis start. The editor has no screen to
    /// resolve `.auto` against, so vertical (auto = a fraction)
    /// uses a fixed pt hint rather than the fraction standard.
    private var currentPoints: CGFloat {
        if case .points(let points) =
            model.config.settings.scrolling.slotSize
        {
            return points
        }
        return isVertical ? 700 : ScrollSize.autoHorizontalPoints
    }

    /// Seed for the Percent unit: keep an explicit fraction, else
    /// the orientation's auto standard (vertical) or a neutral half.
    private var currentFraction: Double {
        if case .fraction(let fraction) =
            model.config.settings.scrolling.slotSize
        {
            return fraction
        }
        return isVertical ? ScrollSize.autoVerticalFraction : 0.5
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
        SettingsSection(
            "Scrolling",
            symbol: LayoutMode.scrolling.glyph
        ) {
            GlassSegmentedPicker(
                "Size unit",
                selection: sizeUnitBinding,
                options: [
                    ("Auto", SizeUnit.auto),
                    ("Points", .points),
                    ("Percent", .percent),
                ]
            )
            sizeControl
            GlassSegmentedPicker(
                "Focused anchor",
                selection: $model.config.settings.scrolling
                    .anchor,
                options: [
                    ("Center", ScrollingParams.Anchor.center),
                    (isVertical ? "Top" : "Left", .left),
                    (isVertical ? "Bottom" : "Right", .right),
                ]
            )
            GlassSegmentedPicker(
                "Scroll orientation",
                selection: $model.config.settings.scrolling
                    .orientation,
                options: [
                    (
                        "Horizontal",
                        ScrollingParams.Orientation.horizontal
                    ),
                    ("Vertical", .vertical),
                ]
            )
            PlacementPicker(
                placement: $model.config.settings.scrolling
                    .newWindowPlacement
            )
            Divider()
            // The scrolling-specific animation pair (#68
            // §3.5): the on/off switch and its magnitude sit
            // together, like a layout's App Bar enable sits
            // above its overrides.
            Toggle(
                "Animate focus shifts",
                isOn: $model.config.settings.animations
                    .onScrolling
            )
            scrollSpeedRow
        }
    }

    /// Stepper for the scrolling focus-shift speed
    /// (`animations.scroll_speed`;
    /// `animations.set_scroll_speed` Lua — #51).
    private var scrollSpeedRow: some View {
        let ms = model.config.settings.animations.scrollSpeedMS
        return HStack {
            Text("Scroll speed")
            Spacer()
            Stepper(
                value: $model.config.settings.animations
                    .scrollSpeedMS,
                in: 50...1000,
                step: 10
            ) {
                Text("\(ms) ms")
                    .frame(minWidth: 52, alignment: .trailing)
                    .monospacedDigit()
            }
        }
        .disabled(
            !model.config.settings.animations.onScrolling
        )
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
        SettingsSection(
            "Grid",
            symbol: LayoutMode.grid.glyph
        ) {
            GlassSegmentedPicker(
                "Grid type",
                selection: $model.config.settings.grid.type,
                options: [
                    ("Dynamic", GridParams.GridType.dynamic),
                    ("Rigid", .rigid),
                ]
            )
            Toggle(
                "Fill empty space",
                isOn: $model.config.settings.grid.fillEmptySpace
            )
            GlassSegmentedPicker(
                "Split direction",
                selection: $model.config.settings.grid
                    .splitDirection,
                options: [
                    (
                        "Horizontal",
                        GridParams.SplitDirection.horizontal
                    ),
                    ("Vertical", .vertical),
                ]
            )
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
