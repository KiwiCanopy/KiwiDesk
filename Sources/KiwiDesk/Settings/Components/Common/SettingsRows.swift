import KiwiDeskCore
import SwiftUI

/// The shared row vocabulary of the settings tabs. Every row
/// puts its label in `SettingsMetrics.labelColumn` (sliders,
/// dropdowns, segmented pickers) or pushes its control to the
/// trailing edge (steppers), so controls of the same kind line
/// up across sections.
///
/// Since #678 turn 17a the label/control arrangement itself is
/// `SettingsRowShape`'s, not each row's: below the row
/// breakpoint the label moves above its control and the shared
/// column stops applying. A row here supplies the two children
/// and never the axis.

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

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(label: label, help: help)
        } control: {
            HStack {
                SettingsSlider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = CGFloat($0) }
                    ),
                    range: range,
                    step: 1,
                    label: label,
                    spokenValue: readoutText
                )
                readout
            }
        }
    }

    private var readoutText: String {
        autoAtZero && value == 0
            ? L("settings.readout.auto", "Automatic")
            : "\(Int(value)) \(unit)"
    }

    private var readout: some View {
        Text(readoutText)
            .settingsReadout()
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

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(label: label, help: help)
        } control: {
            HStack {
                SettingsSlider(
                    value: Binding(
                        get: { Double(ms) / 1000 },
                        set: { ms = Int(($0 * 1000).rounded()) }
                    ),
                    range: range,
                    step: 0.1,
                    label: label,
                    spokenValue: readoutText
                )
                Text(readoutText)
                    .settingsReadout()
                    .frame(
                        width: SettingsMetrics.readoutColumn,
                        alignment: .trailing
                    )
                    .foregroundStyle(.secondary)
                    .font(.body.monospacedDigit())
            }
        }
    }

    private var readoutText: String {
        String(format: "%.1f s", Double(ms) / 1000)
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

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(label: label, help: help)
        } control: {
            HStack {
                SettingsSlider(
                    value: $value,
                    range: 0.1...0.9,
                    step: 0.01,
                    label: label,
                    spokenValue: readoutText
                )
                Text(readoutText)
                    .settingsReadout()
                    .frame(
                        width: SettingsMetrics.readoutColumn,
                        alignment: .trailing
                    )
                    .foregroundStyle(.secondary)
                    .font(.body.monospacedDigit())
            }
        }
    }

    /// Rounded, not truncated: a stored exact 0.29
    /// (Lua/profile) must read "29%", not "28%".
    private var readoutText: String {
        "\(Int((value * 100).rounded()))%"
    }
}

extension View {
    /// A slider row's numeric readout is the control's value
    /// drawn again for the eye; the slider already speaks it
    /// (`SettingsSlider.spokenValue`), so read aloud as well it
    /// is the same number twice, in a third element. Every
    /// readout beside a `SettingsSlider` takes this.
    func settingsReadout() -> some View {
        accessibilityHidden(true)
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
    /// own resting signal is its context — a list row's
    /// neighbours, a drawer header's chevron and hairline.
    /// Unlike icon chips, it adds no fill until the pointer
    /// enters the hit area.
    ///
    /// **That is the whole difference between the two recipes,
    /// and it is a difference of AREA, not of taste** (#956,
    /// owner on device 2026-08-24). `hoverHighlight()`'s 0.06
    /// rest fill is an icon-chip cue: at a glyph's size nobody
    /// reads its hue. Stretched across a full row it composites
    /// to an exactly-neutral band — R=G=B — which is the only
    /// achromatic surface in a green-tinted window, and it
    /// reads as wrong beside a `sunken` well of nearly the same
    /// lightness. A full-row control takes this one.
    ///
    /// The geometry is a parameter so the next full-row control
    /// that needs a different inset does not re-coin the
    /// ladder; the LADDER itself is not a parameter.
    func rowHoverHighlight(
        cornerRadius: CGFloat = 5,
        padding: CGFloat = 0
    ) -> some View {
        hoverHighlight(
            restOpacity: 0,
            hoverOpacity: 0.06,
            cornerRadius: cornerRadius,
            padding: padding
        )
    }
}
