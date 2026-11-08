import KiwiDeskCore
import SwiftUI

/// A share pop-up's "Custom…" (#3062, ruling amendment 2): a
/// typed whole percent, its snap onto the menu's fractions, and the
/// anchored popover that takes it.
enum MaximizeCustomShare {
    /// The tag "Custom…" carries: no share is negative, so it never
    /// collides with a stored value.
    static let tag: Double = -1

    /// The popover's range and arrow step, in percent.
    static let range: ClosedRange<Int> = 10...100
    static let step = 5

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
    static func percent(of share: Double) -> Int {
        Int((share * 100).rounded())
    }
}

/// One presentation of the Custom popover (#843): a fresh id per
/// open keeps the popover's own `@State` fresh.
struct MaximizeCustomRequest: Identifiable, Equatable {
    let id = UUID()
    let seed: Int
}

/// The Custom popover: one percent field with arrows. Return or a
/// click outside commits, Escape cancels; it has no buttons.
struct MaximizeCustomPopover: View {
    /// The column's label, for the spoken name.
    let column: String
    let onCommit: (Int) -> Void
    @State private var percent: Int
    @State private var cancelled = false
    @Environment(\.dismiss) private var dismiss

    init(
        seed: Int,
        column: String,
        onCommit: @escaping (Int) -> Void
    ) {
        self.column = column
        self.onCommit = onCommit
        _percent = State(initialValue: seed)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(L("layout_defaults.maximize.custom.share", "Share"))
                .accessibilityHidden(true)
            // Live commit: a click outside closes the popover without
            // blurring the field first, so `percent` must already
            // hold what is typed.
            StepperRow(
                label: spokenName,
                value: $percent,
                in: MaximizeCustomShare.range,
                step: MaximizeCustomShare.step,
                suffix: L("layout_defaults.maximize.custom.percent", "%"),
                labelHidden: true,
                liveCommit: true
            )
        }
        .padding(12)
        .onSubmit { dismiss() }
        .onExitCommand {
            cancelled = true
            dismiss()
        }
        .onDisappear {
            if !cancelled { onCommit(percent) }
        }
    }

    private var spokenName: String {
        L(
            "layout_defaults.maximize.custom.ax",
            "%1$@, custom share, %2$@ percent",
            column,
            percent.formatted(.number.grouping(.never))
        )
    }
}
