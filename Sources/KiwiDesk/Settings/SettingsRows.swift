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
            Text("\(Int(value)) \(unit)")
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
