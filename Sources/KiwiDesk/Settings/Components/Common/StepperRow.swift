import KiwiDeskCore
import SwiftUI

/// Numeric stepper row with direct text editing field
/// (`HelpButton`, #94, #275).
struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let suffix: String?
    /// Hide visual label while preserving accessibility labels (#275).
    let labelHidden: Bool
    /// Optional contextual help explanation (#94).
    let help: String?
    @State private var text: String
    @FocusState private var focused: Bool
    /// Parse and clamp on keystrokes rather than solely on
    /// blur/commit — for a row whose adjacent action reads `value`
    /// directly: clicking that action on macOS doesn't blur the
    /// field, so the action would use the last committed value
    /// while a newer number sits unread onscreen.
    let liveCommit: Bool

    init(
        label: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        suffix: String? = nil,
        labelHidden: Bool = false,
        help: String? = nil,
        liveCommit: Bool = false
    ) {
        assert(
            !(labelHidden && help != nil),
            "StepperRow drops help when labelHidden — carry "
                + "the help on the section header instead"
        )
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.suffix = suffix
        self.labelHidden = labelHidden
        self.help = help
        self.liveCommit = liveCommit
        self._text = State(initialValue: "\(value.wrappedValue)")
    }

    var body: some View {
        HStack {
            if !labelHidden {
                Text(label)
                if let help {
                    HelpButton(
                        explanation: help,
                        subject: label
                    )
                }
                Spacer()
            }
            TextField("", text: $text)
                .labelsHidden()
                // The field is its own control beside the arrows,
                // and an empty title names it nothing — it said
                // only its digits (#812). Same name as the arrows;
                // its value is the text itself.
                .accessibilityLabel(label)
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
                    guard liveCommit, let parsed = Int(now)
                    else { return }
                    value = min(
                        max(parsed, range.lowerBound),
                        range.upperBound
                    )
                }
            if let suffix {
                Text(suffix).foregroundStyle(.secondary)
            }
            Stepper(value: $value, in: range, step: step) {}
                .labelsHidden()
                .controlSize(.large)
                .accessibilityLabel(label)
                .accessibilityValue(
                    suffix.map { "\(value) \($0)" }
                        ?? "\(value)"
                )
            if labelHidden {
                Spacer()
            }
        }
        // Keep the field in step with arrow taps and external
        // changes — but never mid-edit, or a background write
        // would discard the user's partial entry.
        .onChange(of: value) { _, now in
            if !focused { text = "\(now)" }
        }
    }

    private func commit() {
        if let parsed = Int(text) {
            value = min(max(parsed, range.lowerBound), range.upperBound)
        }
        text = "\(value)"
    }
}
