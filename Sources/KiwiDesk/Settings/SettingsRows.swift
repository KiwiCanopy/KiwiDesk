import KiwiDeskCore
import SwiftUI

/// The shared row vocabulary of the settings tabs. Every row
/// puts its label in `SettingsMetrics.labelColumn` (sliders,
/// dropdowns, segmented pickers) or pushes its control to the
/// trailing edge (steppers), so controls of the same kind line
/// up across sections.

/// A pt-valued slider row with a numeric readout, shared by the
/// monocle and drag-visual editors. The label column comes from
/// the environment, so `OverrideChrome` narrows it once for
/// every row inside.
struct PtSlider: View {
    let label: String
    @Binding var value: CGFloat
    var range: ClosedRange<Double> = 0...100
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            Text(label)
                .frame(width: labelColumn, alignment: .leading)
                .lineLimit(1)
            SettingsSlider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = CGFloat($0) }
                ),
                range: range,
                step: 1
            )
            Text("\(Int(value)) pt")
                .frame(
                    width: SettingsMetrics.readoutColumn,
                    alignment: .trailing
                )
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

/// A 0.1–0.9 ratio slider with a percentage readout.
struct RatioRow: View {
    let label: String
    @Binding var value: Double
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            Text(label)
                .frame(width: labelColumn, alignment: .leading)
                .lineLimit(1)
            SettingsSlider(
                value: $value,
                range: 0.1...0.9,
                step: 0.01
            )
            // Rounded, not truncated: a stored exact 0.29
            // (Lua/profile) must read "29%", not "28%".
            Text("\(Int((value * 100).rounded()))%")
                .frame(
                    width: SettingsMetrics.readoutColumn,
                    alignment: .trailing
                )
                .foregroundStyle(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

/// A dropdown row on the shared label axis: the visible label
/// sits in the label column and the menu button starts on the
/// control line, like every slider and segmented picker. The
/// picker keeps its own title for accessibility
/// (`labelsHidden` hides it visually only).
struct DropdownRow<P: View>: View {
    let label: String
    @ViewBuilder let picker: P
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            Text(label)
                .frame(width: labelColumn, alignment: .leading)
                .lineLimit(1)
            picker
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.large)
            Spacer()
        }
    }
}

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
        suffix: String? = nil
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
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

/// New-window placement picker shared by every layout (BSP,
/// Stack, Scrolling, Grid).
struct PlacementPicker: View {
    @Binding var placement: SpawnPlacement
    /// Row label; defaults to "New window". Track passes
    /// "Position" — it already has a separate own/focused mode
    /// row above, so a second "New window" would read wrong.
    var label: String? = nil

    var body: some View {
        let rowLabel = label ?? newWindowLabel
        return DropdownRow(label: rowLabel) {
            Picker(rowLabel, selection: $placement) {
                Text(L("placement.first", "First"))
                    .tag(SpawnPlacement.first)
                Text(L("placement.last", "Last"))
                    .tag(SpawnPlacement.last)
                Text(
                    L(
                        "placement.before_focused",
                        "Before focused"
                    )
                )
                .tag(SpawnPlacement.beforeFocused)
                Text(
                    L(
                        "placement.after_focused",
                        "After focused"
                    )
                )
                .tag(SpawnPlacement.afterFocused)
            }
        }
    }

    private var newWindowLabel: String {
        L("placement.new_window", "New window")
    }
}

/// Hover-driven background chip for icon-only borderless
/// buttons that otherwise show no cue until pressed — the
/// `ColorSwatch` recipe, generalized: a `RoundedRectangle` fill
/// that lifts from a faint rest state to a stronger one on
/// `.onHover`. Buttons never change the cursor (AGENTS.md); this
/// is chrome only, no `pointingHandCursor()`.
private struct HoverChip: ViewModifier {
    @State private var hovering = false
    var restOpacity: Double
    var hoverOpacity: Double
    var cornerRadius: CGFloat
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        Color.primary.opacity(
                            hovering ? hoverOpacity : restOpacity
                        )
                    )
            )
            .onHover { hovering = $0 }
    }
}

extension View {
    /// Wraps an icon-only borderless control in a hover
    /// background chip (0.06 at rest → 0.12 on hover, matching
    /// `ColorSwatch.swatchButton`), so it reads as clickable
    /// before the pointer commits to a press.
    func hoverHighlight(
        restOpacity: Double = 0.06,
        hoverOpacity: Double = 0.12,
        cornerRadius: CGFloat = 6,
        padding: CGFloat = 4
    ) -> some View {
        modifier(
            HoverChip(
                restOpacity: restOpacity,
                hoverOpacity: hoverOpacity,
                cornerRadius: cornerRadius,
                padding: padding
            )
        )
    }
}
