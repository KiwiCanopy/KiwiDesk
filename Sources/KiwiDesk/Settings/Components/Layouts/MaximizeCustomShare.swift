import KiwiDeskCore
import SwiftUI

/// A share pop-up's "Custom…" (#3062, ruling amendment 2): a
/// typed whole percent, its snap onto the menu's fractions, and the
/// anchored popover that takes it.
@MainActor
enum MaximizeCustomShare {
    /// The tag "Custom…" carries: no share is negative, so it never
    /// collides with a stored value.
    static let tag: Double = -1

    /// The popover's range in percent, Core's clamp (#1359), and
    /// its arrow step.
    static let range: ClosedRange<Int> =
        percent(
            of: MaximizeShape.shareRange.lowerBound
        )...percent(of: MaximizeShape.shareRange.upperBound)
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
/// open, the percent being typed, and whether Escape cancelled it.
/// The row holds it, so the row writes the draft at the dismissal.
struct MaximizeCustomRequest: Identifiable, Equatable {
    let id = UUID()
    /// The stored share as a whole percent, which the field opens on.
    let seed: Int
    var percent: Int
    var cancelled = false

    init(seed: Int) {
        self.seed = seed
        percent = seed
    }
}

/// The Custom popover: one percent field with arrows. Return or a
/// click outside dismisses it, which commits at the row; Escape
/// cancels first. It has no buttons.
struct MaximizeCustomPopover: View {
    @Binding var percent: Int
    /// The column's label, for the spoken name.
    let column: String
    let cancel: () -> Void
    @Environment(\.dismiss) private var dismiss

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
            cancel()
            dismiss()
        }
    }

    private var spokenName: String {
        // The number is the field's and the arrows' value, never
        // the name's (gui.md ▸ a named control is valued).
        L(
            "layout_defaults.maximize.custom.ax",
            "%1$@, custom share",
            column
        )
    }
}
