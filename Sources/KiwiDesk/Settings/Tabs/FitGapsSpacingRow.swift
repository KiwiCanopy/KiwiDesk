import KiwiDeskCore
import SwiftUI

/// Exact-number action parameter in the shared StepperRow shape.
/// Unlike a persisted setting, it live-parses valid input because
/// clicking the adjacent action on macOS does not blur the field;
/// the action must never read a stale value still visible onscreen.
struct FitGapsSpacingRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String
    @State private var text: String
    @FocusState private var focused: Bool

    init(
        label: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        suffix: String
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.suffix = suffix
        self._text = State(initialValue: "\(value.wrappedValue)")
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", text: $text)
                .labelsHidden()
                .frame(width: 48)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, now in
                    if !now { commit() }
                }
                .onChange(of: text) { _, now in
                    if let parsed = Int(now) {
                        value = clamped(parsed)
                    }
                }
                .accessibilityLabel(label)
                .accessibilityValue(accessibilityValue)
            Text(suffix)
                .foregroundStyle(.secondary)
            Stepper(value: $value, in: range) {}
                .labelsHidden()
                .controlSize(.large)
                .accessibilityLabel(label)
                .accessibilityValue(accessibilityValue)
        }
        .onChange(of: value) { _, now in
            if !focused { text = "\(now)" }
        }
    }

    private func clamped(_ raw: Int) -> Int {
        min(max(raw, range.lowerBound), range.upperBound)
    }

    private var accessibilityValue: String {
        L(
            "border.fit_gaps.spacing.a11y_value",
            "%1$d points",
            value
        )
    }

    private func commit() {
        if let parsed = Int(text) {
            value = clamped(parsed)
        }
        text = "\(value)"
    }
}
