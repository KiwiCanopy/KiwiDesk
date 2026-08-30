import KiwiDeskCore
import SwiftUI

/// Unit picker and slider controls for scrolling layout slot size (ui-designer
/// 2026-07-29).
struct SlotSizeRows: View {
    @ObservedObject var model: SettingsModel
    /// Slot size binding for global settings or space override (#290).
    @Binding var size: ScrollSize
    /// Whether layout orientation is vertical (swaps labels and seeds).
    let isVertical: Bool
    /// Part of control to render (#68).
    var part: Part = .both

    /// Unit picker presentation style (#291).
    var unitStyle: UnitStyle = .segmented

    enum UnitStyle { case segmented, menu }

    enum Part { case unit, control, both }

    private var sizeLabel: String {
        isVertical
            ? L("slot_size.row_height", "Row height")
            : L("slot_size.column_width", "Column width")
    }

    /// Points slider floor clamped by global minimum window size.
    private var minPointsFloor: Double {
        Double(min(model.config.settings.minWindowSize, 1990))
    }

    /// Range for percentage slider (`SlotSizePercentRangeTests`).
    static let percentRange: ClosedRange<Double> = 5...100
    /// Step size for percentage slider.
    static let percentStep: Double = 1

    private enum SizeUnit: Hashable {
        case points, percent
    }

    /// Resolves presentation unit from stored `ScrollSize`.
    private var sizeUnit: SizeUnit {
        switch size {
        case .auto, .fraction: return .percent
        case .points: return .points
        }
    }

    /// Seed points value clamped to valid range.
    private var currentPoints: CGFloat {
        let stored: CGFloat
        if case .points(let points) =
            size
        {
            stored = points
        } else {
            stored = isVertical ? 700 : 1100
        }
        return max(stored, CGFloat(minPointsFloor))
    }

    /// Seed fraction value using default orientation auto fraction.
    private var currentFraction: Double {
        if case .fraction(let fraction) =
            size
        {
            return fraction
        }
        return isVertical
            ? ScrollSize.autoVerticalFraction
            : ScrollSize.autoHorizontalFraction
    }

    private var sizeUnitBinding: Binding<SizeUnit> {
        Binding(
            get: { sizeUnit },
            set: { unit in
                switch unit {
                case .points:
                    size =
                        .points(currentPoints)
                case .percent:
                    size =
                        .fraction(currentFraction)
                }
            }
        )
    }

    private var pointsBinding: Binding<Double> {
        Binding(
            get: { Double(currentPoints) },
            set: {
                size =
                    .points(CGFloat($0))
            }
        )
    }

    private var percentBinding: Binding<Double> {
        Binding(
            get: { currentFraction * 100 },
            set: {
                size =
                    .fraction($0 / 100)
            }
        )
    }

    @ViewBuilder
    var body: some View {
        switch part {
        case .unit:
            unitPicker
        case .control:
            sizeControl
        case .both:
            unitPicker
            sizeControl
        }
    }

    private var unitOptions: [(String, SizeUnit)] {
        [
            // Percent leads: it is the shipped default's unit and
            // the recommended one (it keeps the slot's share of
            // the screen across displays).
            (L("slot_size.percent", "Percent"), SizeUnit.percent),
            (L("slot_size.points", "Points"), .points),
        ]
    }

    @ViewBuilder
    private var unitPicker: some View {
        switch unitStyle {
        case .segmented:
            SegmentedPicker(
                L("slot_size.unit", "Size unit"),
                selection: sizeUnitBinding,
                options: unitOptions
            )
        case .menu:
            DropdownRow(
                label: L("slot_size.unit", "Size unit"),
                spokenValue: unitOptions.first { $0.1 == sizeUnit }?.0
                    ?? ""
            ) {
                Picker(
                    L("slot_size.unit", "Size unit"),
                    selection: sizeUnitBinding
                ) {
                    ForEach(unitOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var sizeControl: some View {
        switch sizeUnit {
        case .points:
            SettingsRowShape {
                SettingsRowLabel(label: sizeLabel)
            } control: {
                HStack {
                    SettingsSlider(
                        // Floored at the global minimum window
                        // size: the layout clamps a smaller slot
                        // up to it anyway, so the control
                        // shouldn't offer below it.
                        value: pointsBinding,
                        range: minPointsFloor...2000,
                        step: 10,
                        label: sizeLabel,
                        spokenValue: pointsReadout
                    )
                    readout(pointsReadout)
                }
            }
        case .percent:
            SettingsRowShape {
                SettingsRowLabel(label: sizeLabel)
            } control: {
                HStack {
                    SettingsSlider(
                        value: percentBinding,
                        range: Self.percentRange,
                        step: Self.percentStep,
                        label: sizeLabel,
                        spokenValue: percentReadout
                    )
                    readout(percentReadout)
                }
            }
        }
    }

    private var pointsReadout: String {
        "\(Int(currentPoints)) pt"
    }

    private var percentReadout: String {
        "\(Int(currentFraction * 100)) %"
    }

    private func readout(_ text: String) -> some View {
        Text(text)
            .settingsReadout()
            .frame(
                width: SettingsMetrics.readoutColumn,
                alignment: .trailing
            )
            .foregroundStyle(.secondary)
            .font(.body.monospacedDigit())
    }
}
