import KiwiDeskCore
import SwiftUI

/// The scrolling slot-size pair: the unit picker (Auto /
/// Points / Percent) and the value row it drives — a slider in
/// the explicit units, a value chip in Auto. Split out of
/// `ScrollGridEditor` so the unit seeds and bindings live with
/// the rows they feed.
struct SlotSizeRows: View {
    @ObservedObject var model: SettingsModel
    /// The slot size the rows edit. Injected as a binding so the
    /// same unit picker + value control drives both the global
    /// scrolling params and the per-space `ScrollSize?` override
    /// (via `overrideValue`, #290) — one control, no hand-rolled
    /// second copy to drift (§5).
    @Binding var size: ScrollSize
    /// Swaps the label to "Row height" and the pt seed to the
    /// vertical default (frontend only; the stored `slot_size`
    /// is orientation-neutral).
    let isVertical: Bool
    /// Which half to render: the unit picker groups with the
    /// other segmented pickers, the value control re-homes
    /// below them (#68) — `.both` keeps the paired default.
    var part: Part = .both

    /// How the unit picker renders. `.segmented` on the full-width
    /// Layout Defaults surface, where it lines up with the
    /// orientation/anchor segmented pickers; `.menu` in the narrow
    /// per-Space override popover, matching that surface's other
    /// (dropdown) override rows — the #291 compact-surface
    /// exception, where segments would be cramped.
    var unitStyle: UnitStyle = .segmented

    enum UnitStyle { case segmented, menu }

    /// The label-column width, read from the environment like the
    /// sibling row types (`PtSlider`, `RatioRow`), so the value
    /// row narrows to the override column when `OverrideChrome`
    /// wraps it and stays at the full width otherwise (#290).
    @Environment(\.settingsLabelColumn) private var labelColumn

    enum Part { case unit, control, both }

    private var sizeLabel: String {
        isVertical
            ? L("slot_size.row_height", "Row height")
            : L("slot_size.column_width", "Column width")
    }

    /// The points slider's floor: the global minimum window size
    /// (the layout clamps anything smaller up to it). Capped under
    /// the slider max so the range can never invert.
    private var minPointsFloor: Double {
        Double(min(model.config.settings.minWindowSize, 1990))
    }

    private enum SizeUnit: Hashable {
        case auto, points, percent
    }

    private var sizeUnit: SizeUnit {
        switch size {
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
        let stored: CGFloat
        if case .points(let points) =
            size
        {
            stored = points
        } else {
            stored =
                isVertical ? 700 : ScrollSize.autoHorizontalPoints
        }
        // Keep the readout and slider thumb inside the slider's
        // range; a smaller stored slot is floored at minWindowSize
        // by the engine anyway.
        return max(stored, CGFloat(minPointsFloor))
    }

    /// Seed for the Percent unit: keep an explicit fraction, else
    /// the orientation's auto standard (vertical) or a neutral half.
    private var currentFraction: Double {
        if case .fraction(let fraction) =
            size
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
                    size = .auto
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
            // "Default" (not "Auto"): it's a fixed built-in size,
            // not an adaptive/auto-fitting one — the grid's
            // "Auto-size" owns that meaning.
            (L("slot_size.auto", "Default"), SizeUnit.auto),
            (L("slot_size.points", "Points"), .points),
            (L("slot_size.percent", "Percent"), .percent),
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
            DropdownRow(label: L("slot_size.unit", "Size unit")) {
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
        case .auto:
            HStack {
                Text(sizeLabel)
                    .frame(
                        width: labelColumn,
                        alignment: .leading
                    )
                // A value chip, not prose: the row where the
                // slider lives in the other units shows the
                // resolved state in the chips' capsule
                // language, so it can't be read over as filler
                // text.
                Text(
                    L(
                        "slot_size.auto_standard",
                        "Default — orientation standard"
                    )
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(.secondary.opacity(0.08))
                )
                .overlay(
                    Capsule().strokeBorder(
                        .secondary.opacity(0.15),
                        lineWidth: 0.5
                    )
                )
                Spacer()
            }
        case .points:
            HStack {
                Text(sizeLabel)
                    .frame(
                        width: labelColumn,
                        alignment: .leading
                    )
                SettingsSlider(
                    // Floored at the global minimum window size: the
                    // layout clamps a smaller slot up to it anyway,
                    // so the control shouldn't offer below it.
                    value: pointsBinding,
                    range: minPointsFloor...2000,
                    step: 10
                )
                Text("\(Int(currentPoints)) pt")
                    .frame(
                        width: SettingsMetrics.readoutColumn,
                        alignment: .trailing
                    )
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
        case .percent:
            HStack {
                Text(sizeLabel)
                    .frame(
                        width: labelColumn,
                        alignment: .leading
                    )
                SettingsSlider(
                    value: percentBinding,
                    range: 5...100,
                    step: 5
                )
                Text("\(Int(currentFraction * 100)) %")
                    .frame(
                        width: SettingsMetrics.readoutColumn,
                        alignment: .trailing
                    )
                    .foregroundStyle(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
}
