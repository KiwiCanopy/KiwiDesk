import KiwiDeskCore
import SwiftUI

/// A stepper row in the duration rows' shape: label leading,
/// the value trailing as an **editable field** (type a number
/// or use the arrows) plus the stepper arrows — the native
/// System-Settings numeric layout, with the value reading as
/// changeable, not a static readout. An optional `suffix` (e.g.
/// "ms") sits between the field and the arrows.
struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let suffix: String?
    /// Hide the visual label, leaving value + arrows only (#275):
    /// for a section whose header already names the sole control,
    /// restating it on the row is native-atypical (Dock "Size").
    /// `label` still feeds the accessibility label, so VoiceOver
    /// is unaffected — the control is left-aligned under the
    /// header instead of trailing an empty label column.
    let labelHidden: Bool
    /// Optional #94 `?` popover, label-adjacent like the other
    /// row kinds. Ignored while `labelHidden` — a floating `?`
    /// with no visible subject reads unanchored; such sections
    /// carry their help on the header instead.
    let help: String?
    /// The field edits a string proxy so intermediate/empty
    /// typing never clobbers `value`; it commits (parse +
    /// clamp) on Return or focus loss, matching the rename
    /// field's commit discipline.
    @State private var text: String
    @FocusState private var focused: Bool

    init(
        label: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        suffix: String? = nil,
        labelHidden: Bool = false,
        help: String? = nil
    ) {
        // The drop is deliberate (see `help` above) — make the
        // contract self-enforcing rather than silent.
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
                .frame(width: 48)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, now in
                    if !now { commit() }
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
            // Label hidden → nothing anchors the control to the
            // leading edge, so a trailing spacer keeps it left
            // under the section header instead of centering.
            if labelHidden {
                Spacer()
            }
        }
        // Keep the field in step with arrow taps / external
        // changes — but never while the user is mid-edit, or a
        // background write would discard their partial entry.
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
