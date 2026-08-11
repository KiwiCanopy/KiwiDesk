import KiwiDeskCore
import SwiftUI

/// The scrolling slot-size pair: the unit picker (Percent /
/// Points) and the slider row it drives. A stored `.auto`
/// renders as Percent at the orientation standard — the GUI
/// stopped offering "Default" as a third unit once both axes'
/// standards became the same fraction (ui-designer,
/// 2026-07-29; see `docs/design-decisions.md`), while `.auto`
/// itself stays in the model and Lua (`scroll.set_slot_size(0)`).
/// Split out of `ScrollGridEditor` so the unit seeds and
/// bindings live with the rows they feed.
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
    /// orientation/anchor segmented pickers; `.menu` in the
    /// per-space override editor, matching that surface's other
    /// (dropdown) override rows — the #291 compact-surface
    /// exception, where its bounded rows column would cramp
    /// segments.
    var unitStyle: UnitStyle = .segmented

    enum UnitStyle { case segmented, menu }

    // The label-column width is `SettingsRowShape`'s to read
    // (#290's environment override still applies — the shape
    // reads the same `settingsLabelColumn`, so the value row
    // still narrows inside `OverrideChrome` and still reflows
    // with every other row below the 17a row breakpoint).

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

    /// The Percent slider's range, spanning what the model
    /// stores: the floor is `ScrollSize.minFraction` — below it
    /// the setter clamps, so a lower stop would report a slot
    /// the config never holds — and the ceiling is the whole
    /// axis, which is a slot KiwiDesk renders rather than a
    /// broken value. Internal so `SlotSizePercentRangeTests` can
    /// hold it against the model's own bounds.
    static let percentRange: ClosedRange<Double> = 5...100
    /// The Percent slider's granularity. 1%, because a percent
    /// of a scroll axis is a visible amount of window — ~19 pt
    /// of column on a 1920 display — so every stop moves
    /// something the user can see, and the shipped standard
    /// stays a stop whatever it is: a default the slider cannot
    /// return to reads as a bug.
    static let percentStep: Double = 1

    private enum SizeUnit: Hashable {
        case points, percent
    }

    /// `.auto` presents as Percent: it resolves to the standard
    /// fraction on either axis, so Percent at that fraction is its
    /// truthful rendering. The stored value stays `.auto` until the user
    /// moves the slider (the binding then writes an explicit
    /// `.fraction`) — an untouched config keeps tracking the
    /// shipped standard.
    private var sizeUnit: SizeUnit {
        switch size {
        case .auto, .fraction: return .percent
        case .points: return .points
        }
    }

    /// Seed for the Points unit: keep an explicit pt, else a
    /// sensible per-axis start. The editor has no screen to
    /// resolve `.auto` (a fraction on both axes) against, so each
    /// axis uses a fixed pt hint rather than the fraction standard.
    private var currentPoints: CGFloat {
        let stored: CGFloat
        if case .points(let points) =
            size
        {
            stored = points
        } else {
            stored = isVertical ? 700 : 1100
        }
        // Keep the readout and slider thumb inside the slider's
        // range; a smaller stored slot is floored at minWindowSize
        // by the engine anyway.
        return max(stored, CGFloat(minPointsFloor))
    }

    /// Seed for the Percent unit: keep an explicit fraction, else
    /// the orientation's auto standard.
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
                        step: 10
                    )
                    readout("\(Int(currentPoints)) pt")
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
                        step: Self.percentStep
                    )
                    readout("\(Int(currentFraction * 100)) %")
                }
            }
        }
    }

    private func readout(_ text: String) -> some View {
        Text(text)
            .frame(
                width: SettingsMetrics.readoutColumn,
                alignment: .trailing
            )
            .foregroundStyle(.secondary)
            .font(.body.monospacedDigit())
    }
}
