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
    /// The readout unit; `pt` by default, `%` for proportion
    /// sliders (e.g. the App Bar corner roundness).
    var unit: String = "pt"
    /// Opt-in: 0 is this slider's Auto sentinel (an
    /// `AutoGatedGroup` toggle wrote it), so the readout says
    /// "Automatic" instead of "0 pt" — the full word, because a
    /// readout is a VALUE the user reads, not the adjective in a
    /// toggle label (R6/#406). It is the widest thing the readout
    /// column has to hold; see `SettingsMetrics.readoutColumn`.
    /// Explicit, never inferred from
    /// the range — a 1-floored slider without a sentinel must
    /// keep printing its number (QA 2026-07-19).
    var autoAtZero: Bool = false
    /// Optional `?` popover (#94), label-adjacent and inside the
    /// shared label column — the same slot `SecondsRow` and
    /// `RatioRow` carry. Declared LAST so a call site can pass
    /// it while leaving `unit` and `autoAtZero` at their
    /// defaults.
    var help: String? = nil
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(label).lineLimit(1)
                if let help {
                    HelpButton(explanation: help, subject: label)
                }
            }
            .frame(width: labelColumn, alignment: .leading)
            SettingsSlider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = CGFloat($0) }
                ),
                range: range,
                step: 1
            )
            Text(
                autoAtZero && value == 0
                    ? L("settings.readout.auto", "Automatic")
                    : "\(Int(value)) \(unit)"
            )
            .frame(
                width: SettingsMetrics.readoutColumn,
                alignment: .trailing
            )
            .foregroundStyle(.secondary)
            .font(.body.monospacedDigit())
            // A locale whose word for "Automatic" runs longer
            // than the column shrinks rather than truncating —
            // a clipped readout reads as a rendering bug, a
            // slightly smaller one does not. Load-bearing: the
            // word ONLY renders on an `AutoGatedGroup`-gated
            // row, so it is always dimmed and disabled beside
            // full-size numbers — a slightly smaller word there
            // reads as "inert", not "broken". Don't "fix" the
            // scale factor away.
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
    }
}

/// A seconds-valued slider backed by a millisecond `Int` store,
/// with a `1.5 s` readout — the Space Bar drag-drop spring dwell
/// (#372). Bounds come in seconds; the binding converts to/from
/// the stored milliseconds.
struct SecondsRow: View {
    let label: String
    @Binding var ms: Int
    var range: ClosedRange<Double> = 0.5...4.0
    /// Optional `?` popover (#94), label-adjacent.
    var help: String? = nil
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(label).lineLimit(1)
                if let help {
                    HelpButton(explanation: help, subject: label)
                }
            }
            .frame(width: labelColumn, alignment: .leading)
            SettingsSlider(
                value: Binding(
                    get: { Double(ms) / 1000 },
                    set: { ms = Int(($0 * 1000).rounded()) }
                ),
                range: range,
                step: 0.1
            )
            Text(
                String(format: "%.1f s", Double(ms) / 1000)
            )
            .frame(
                width: SettingsMetrics.readoutColumn,
                alignment: .trailing
            )
            .foregroundStyle(.secondary)
            .font(.body.monospacedDigit())
        }
    }
}

/// A 0.1–0.9 ratio slider with a percentage readout.
struct RatioRow: View {
    let label: String
    @Binding var value: Double
    /// Optional `?` popover (#94), label-adjacent: the
    /// question is born at the label, so the affordance sits
    /// where the confusion starts.
    var help: String? = nil
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(label).lineLimit(1)
                if let help {
                    HelpButton(explanation: help, subject: label)
                }
            }
            .frame(width: labelColumn, alignment: .leading)
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
                .font(.body.monospacedDigit())
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
    /// Optional `?` popover (#94), label-adjacent.
    var help: String? = nil
    @ViewBuilder let picker: P
    @Environment(\.settingsLabelColumn)
    private var labelColumn

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Text(label).lineLimit(1)
                if let help {
                    HelpButton(explanation: help, subject: label)
                }
            }
            .frame(width: labelColumn, alignment: .leading)
            picker
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.large)
            Spacer()
        }
    }
}

/// A labeled toggle carrying an optional #94 `?`. A plain
/// `Toggle` has no help slot, so the switches that want one (wrap
/// focus, the App Bar group-adjacent toggle) route through this.
/// The `?` is a **sibling** after the toggle, never nested inside
/// its label: these render in the checkbox style (box left, label
/// right — a plain `VStack`, not a `Form`), so a trailing sibling
/// still lands immediately after the label text (#94 placement),
/// and staying a sibling keeps the `?` an independent hit target
/// and VoiceOver rotor stop instead of one the Toggle swallows.
/// `fixedSize` makes the toggle hug its label so the `?` sits
/// adjacent rather than pushed to the pane edge. Unlike the
/// dropdown/ratio rows the `?` can't sit inside the shared
/// `settingsLabelColumn` — a native toggle is full-width — so it
/// trails variable-width label text instead of column-aligning.
struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    /// Optional `?` popover (#94). Omit for a self-evident toggle.
    var help: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Toggle(isOn: $isOn) { Text(label) }
                .fixedSize()
            if let help {
                HelpButton(explanation: help, subject: label)
            }
        }
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
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
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
                            hovering && isEnabled
                                ? hoverOpacity : restOpacity
                        )
                    )
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: hovering
            )
            .onHover { hovering = isEnabled && $0 }
            .onChange(of: isEnabled) { _, now in
                if !now { hovering = false }
            }
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

    /// Complete treatment for an ambiguous icon-only button:
    /// visible chip, pointer confirmation, tooltip, and a real
    /// VoiceOver name. The call site supplies one action phrase
    /// so those four surfaces cannot drift.
    func iconButtonAffordance(
        _ label: String,
        cornerRadius: CGFloat = 4,
        padding: CGFloat = 2
    ) -> some View {
        hoverHighlight(
            cornerRadius: cornerRadius,
            padding: padding
        )
        .help(label)
        .accessibilityLabel(label)
    }

    /// Hover confirmation for a custom full-row button whose
    /// list context is its rest affordance. Unlike icon chips,
    /// it adds no fill until the pointer enters the hit area.
    func rowHoverHighlight() -> some View {
        hoverHighlight(
            restOpacity: 0,
            hoverOpacity: 0.06,
            cornerRadius: 5,
            padding: 0
        )
    }
}
