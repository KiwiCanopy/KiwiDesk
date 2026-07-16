import KiwiDeskCore
import SwiftUI

/// The compact remaining-gap field (#295), extracted from
/// `FocusBorderEditor` for the file-size target.
///
/// Every keystroke live-parses into `value` (clamped to
/// `BorderStyle.remainingGapRange`): on macOS, clicking a plain
/// button does NOT move focus out of a text field, so a
/// commit-only-on-blur proxy would let the adjacent "Adjust
/// gaps" action read a stale value while the field visibly
/// shows the new one. Return or focus loss additionally
/// normalizes the text back to the committed number (the
/// StepperRow discipline), so mid-edit garbage never sticks.
struct RemainingGapField: View {
    @Binding var value: Int
    @State private var text = "0"
    @FocusState private var focused: Bool

    private var range: ClosedRange<Int> {
        let bounds = BorderStyle.remainingGapRange
        return Int(bounds.lowerBound)...Int(bounds.upperBound)
    }

    var body: some View {
        TextField("", text: $text)
            .labelsHidden()
            .frame(width: 44)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .onSubmit(commit)
            .onChange(of: focused) { _, now in
                if !now { commit() }
            }
            .onChange(of: text) { _, now in
                // Live commit — see the type comment. The text
                // itself is left alone mid-edit; only parseable
                // input moves the value.
                if let parsed = Int(now) {
                    value = clamped(parsed)
                }
            }
            .accessibilityLabel(
                L(
                    "border.remaining_gap.a11y",
                    "Remaining gap after borders"
                )
            )
    }

    private func clamped(_ raw: Int) -> Int {
        min(max(raw, range.lowerBound), range.upperBound)
    }

    private func commit() {
        if let parsed = Int(text) {
            value = clamped(parsed)
        }
        text = "\(value)"
    }
}
