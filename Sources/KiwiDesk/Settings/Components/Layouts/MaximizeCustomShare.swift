import KiwiDeskCore
import SwiftUI

/// A share pop-up's "Custom…" (#3062 ruling amendment 2, #3460): a
/// typed whole percent, which snaps onto the menu's fractions, or a
/// typed whole length in points, which never snaps, and the anchored
/// popover that takes either.
@MainActor
enum MaximizeCustomShare {
    /// The popover's percent range, Core's clamp (#1359), and its
    /// arrow step.
    nonisolated static var range: ClosedRange<Int> {
        percent(
            of: MaximizeLength.fractionRange.lowerBound
        )...percent(of: MaximizeLength.fractionRange.upperBound)
    }
    static let step = 5

    /// The lengths Custom… stores (#3460): whole points from 200,
    /// with no cap tied to one screen. The ceiling only bounds the
    /// field.
    nonisolated static let pointsRange = 200...20_000
    static let pointsStep = 10

    /// The share a typed percent stores: a menu fraction's exact
    /// value where the percent rounds to it (33 stores ⅓, so the
    /// menu checks it), else the percent itself.
    static func share(forPercent percent: Int) -> Double {
        let clamped = min(max(percent, range.lowerBound), range.upperBound)
        return FractionChips.shares.first {
            Int(($0.value * 100).rounded()) == clamped
        }?.value ?? Double(clamped) / 100
    }

    /// The whole percent a stored share seeds the popover with.
    nonisolated static func percent(of share: Double) -> Int {
        Int((share * 100).rounded())
    }

    /// The length `share` fills along the other axis of `axis` on a
    /// screen of `screen`'s visible frame: the fill's own
    /// resolution, so a readout never multiplies a share itself
    /// (state-and-layout.md ▸ Maximize length). Nil with no screen.
    static func points(
        of share: MaximizeLength,
        axis: MaximizeAxis,
        screen: CGRect?
    ) -> CGFloat? {
        guard let screen else { return nil }
        let rect = TilingEngine.maximizedBounds(
            MaximizeShape(axis: axis, share: share),
            screen: CGRect(origin: .zero, size: screen.size),
            slot: .zero
        )
        return axis == .height ? rect.width : rect.height
    }
}

/// The unit a Custom popover types in (#3460).
enum MaximizeCustomUnit: Hashable {
    case percent
    case points
}

/// One presentation of the Custom popover (#843): a fresh id per
/// open, the unit and number being typed, and whether Escape
/// cancelled it. The row holds it, so the row writes the draft at
/// the dismissal. A number of 0 is an empty field: a unit flip with
/// no screen to convert on clears it.
struct MaximizeCustomRequest: Identifiable, Equatable {
    let id = UUID()
    /// What the field opened on, which a dismissal leaves alone.
    let seed: MaximizeLength
    /// The axis the share sizes the other of.
    let axis: MaximizeAxis
    /// The visible frame of this row's screen, which a unit flip
    /// converts on; nil with no screen of that shape.
    let screen: CGRect?
    var unit: MaximizeCustomUnit
    var number: Int
    var cancelled = false

    init(stored: MaximizeLength, axis: MaximizeAxis, screen: CGRect?) {
        seed = stored
        self.axis = axis
        self.screen = screen
        switch stored {
        case .fraction(let fraction):
            unit = .percent
            number = MaximizeCustomShare.percent(of: fraction)
        case .points(let points):
            unit = .points
            number = Int(points.rounded())
        }
    }

    /// The share the dismissal writes: nil where Escape cancelled,
    /// the field is empty or the stored share still reads as typed.
    @MainActor var committed: MaximizeLength? {
        guard !cancelled, number > 0, let typed = typed,
            !typed.matches(seed)
        else { return nil }
        return typed
    }

    @MainActor private var typed: MaximizeLength? {
        switch unit {
        case .percent:
            let range = MaximizeCustomShare.range
            guard range.contains(number) else { return nil }
            if case .fraction(let stored) = seed,
                MaximizeCustomShare.percent(of: stored) == number
            {
                return seed
            }
            return .fraction(MaximizeCustomShare.share(forPercent: number))
        case .points:
            let range = MaximizeCustomShare.pointsRange
            guard range.contains(number) else { return nil }
            return .points(CGFloat(number))
        }
    }

    /// Switches the field to `next`, converting the number on this
    /// row's screen through the fill's own resolution; with no
    /// screen the field clears.
    @MainActor mutating func flip(to next: MaximizeCustomUnit) {
        guard next != unit else { return }
        defer { unit = next }
        let fraction = MaximizeLength.fraction(Double(number) / 100)
        guard number > 0,
            let whole = MaximizeCustomShare.points(
                of: .fraction(1),
                axis: axis,
                screen: screen
            ),
            whole > 0
        else {
            number = 0
            return
        }
        switch next {
        case .points:
            let points =
                MaximizeCustomShare.points(
                    of: fraction,
                    axis: axis,
                    screen: screen
                ) ?? 0
            let range = MaximizeCustomShare.pointsRange
            number = min(
                max(Int(points), range.lowerBound),
                range.upperBound
            )
        case .percent:
            // The inverse: what share of the screen a length is.
            let percent = (CGFloat(number) / whole * 100).rounded()
            let range = MaximizeCustomShare.range
            number = min(max(Int(percent), range.lowerBound), range.upperBound)
        }
    }
}

/// The Custom popover: a `% | pt` switch and one field with arrows.
/// Return or a click outside dismisses it, which commits at the
/// row; Escape cancels first. It has no buttons.
struct MaximizeCustomPopover: View {
    @Binding var request: MaximizeCustomRequest
    /// The column's label, for the spoken name.
    let column: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SegmentedPicker(
                L("slot_size.unit", "Size unit"),
                selection: Binding(
                    get: { request.unit },
                    set: { request.flip(to: $0) }
                ),
                options: [
                    (L("slot_size.percent", "Percent"), .percent),
                    (L("slot_size.points", "Points"), .points),
                ]
            )
            HStack(spacing: 8) {
                Text(L("layout_defaults.maximize.custom.share", "Share"))
                    .accessibilityHidden(true)
                // Live commit: a click outside closes the popover
                // without blurring the field first, so `number` must
                // already hold what is typed. Keyed on the unit, so a
                // flip opens a fresh field on the converted number.
                StepperRow(
                    label: spokenName,
                    value: $request.number,
                    in: request.unit == .percent
                        ? MaximizeCustomShare.range
                        : MaximizeCustomShare.pointsRange,
                    step: request.unit == .percent
                        ? MaximizeCustomShare.step
                        : MaximizeCustomShare.pointsStep,
                    suffix: request.unit == .percent
                        ? L("layout_defaults.maximize.custom.percent", "%")
                        : L("layout_defaults.maximize.custom.points", "pt"),
                    labelHidden: true,
                    liveCommit: true
                )
                .id(request.unit)
            }
        }
        .padding(12)
        .onSubmit { dismiss() }
        .onExitCommand {
            request.cancelled = true
            dismiss()
        }
    }

    private var spokenName: String {
        // The number is the field's and the arrows' value, never
        // the name's (gui.md ▸ a named control is valued).
        L(
            "layout_defaults.maximize.custom.ax",
            "%1$@, custom size",
            column
        )
    }
}
