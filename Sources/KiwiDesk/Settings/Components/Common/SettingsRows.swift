import KiwiDeskCore
import SwiftUI

/// Shared row vocabulary for settings tabs aligned across sections (#678).

/// Point-valued slider row with formatted numeric readout (#406, #94).
struct PtSlider: View {
    let label: String
    @Binding var value: CGFloat
    var range: ClosedRange<Double> = 0...100
    var unit: String = "pt"
    /// Opt-in: 0 is this slider's Auto sentinel, read out as the
    /// full word (R6/#406). Explicit, never inferred from the
    /// range — a 1-floored slider without a sentinel must keep
    /// printing its number (QA 2026-07-19).
    var autoAtZero: Bool = false
    /// What Auto draws right now, where the caller can say: the
    /// slider then sits at it and the readout shows it, so the
    /// user sees the size before taking it over (#1713).
    var autoValue: CGFloat? = nil
    var help: String? = nil

    private var isAuto: Bool { autoAtZero && value == 0 }

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(label: label, help: help)
        } control: {
            HStack {
                SettingsSlider(
                    value: Binding(
                        get: { sliderPosition },
                        set: { value = CGFloat($0) }
                    ),
                    range: range,
                    step: 1,
                    label: label,
                    spokenValue: spokenText
                )
                readout
            }
        }
    }

    /// Where the slider sits: under Auto, the size Auto draws.
    var sliderPosition: Double {
        Double(isAuto ? autoValue ?? 0 : value)
    }

    private func points(_ size: CGFloat) -> String {
        "\(Int(size.rounded())) \(unit)"
    }

    var readoutText: String {
        guard isAuto else { return points(value) }
        return autoValue.map(points)
            ?? L("settings.readout.auto", "Automatic")
    }

    var spokenText: String {
        guard isAuto, let autoValue else { return readoutText }
        return L(
            "settings.readout.auto_value",
            "Automatic, %1$@",
            points(autoValue)
        )
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
            // A long localized "Automatic" shrinks rather than
            // truncates. Load-bearing: the word only renders
            // dimmed beside full-size numbers, so smaller reads
            // as inert, not broken — don't "fix" the scale
            // factor away.
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

/// Slider row formatted in fractional seconds with millisecond storage (#372,
/// #94).
struct SecondsRow: View {
    let label: String
    @Binding var ms: Int
    var range: ClosedRange<Double> = 0.5...4.0
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

/// Ratio slider row formatted in percentage (0.1–0.9) (#94).
/// A split's share of its span, with the fraction chips a share
/// takes rather than a count (#1382): ¼ ⅓ ½ ⅔ ¾ snap the slider
/// (`FractionChipsTests`).
struct RatioRow: View {
    let label: String
    @Binding var value: Double
    var help: String? = nil
    /// The share's legal band — a split's by default.
    var range: ClosedRange<Double> = 0.1...0.9

    var body: some View {
        SliderPresetRow(
            label: label,
            help: help,
            value: $value,
            range: range,
            step: 0.01,
            readout: readoutText,
            spokenValue: readoutText
        ) {
            FractionChips(value: $value, label: label)
        }
    }

    /// One formatter with the pill (#1382): a stored exact 0.29
    /// reads "29%", a third "33.33%".
    private var readoutText: String {
        SettingsValueReadout.percent(value)
    }
}

extension View {
    /// Hides redundant visual readout from VoiceOver since slider speaks its
    /// value.
    func settingsReadout() -> some View {
        accessibilityHidden(true)
    }
}

/// Labeled checkbox toggle row with optional help popover (#94).
/// The `?` is a sibling after the toggle, never nested in its
/// label — an independent hit target and rotor stop the Toggle
/// would otherwise swallow. `disabled` greys the checkbox alone:
/// a `.disabled` on the row would kill the `?` too (#527).
struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    var help: String? = nil
    var disabled: Bool = false

    /// A line under the row starts at the checkbox's label.
    static let captionIndent: CGFloat =
        SettingsMetrics.checkboxWidth + SettingsMetrics.checkboxLabelGap

    var body: some View {
        HStack(spacing: 4) {
            Toggle(isOn: $isOn) { Text(label) }
                .fixedSize()
                .disabled(disabled)
            if let help {
                HelpButton(explanation: help, subject: label)
            }
        }
    }
}

/// Hover-driven chip behind a borderless control: a rest fill, a
/// hover lift and, for a text button chip, a constant edge.
private struct HoverChip: ViewModifier {
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    var rest: Color
    var hover: Color
    var edge: Color?
    var cornerRadius: CGFloat
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(hovering && isEnabled ? hover : rest)
            )
            .overlay {
                if let edge {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(edge, lineWidth: 1)
                }
            }
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
    /// The button chip tier by default: rest and hover fills from
    /// the chip tokens and the text button chip's edge (#2047).
    /// The icon and row tiers pass their own.
    func hoverHighlight(
        rest: Color = SettingsTheme.chipRest,
        hover: Color = SettingsTheme.chipHover,
        edge: Color? = SettingsTheme.chipEdge,
        cornerRadius: CGFloat = 6,
        padding: CGFloat = 4
    ) -> some View {
        modifier(
            HoverChip(
                rest: rest,
                hover: hover,
                edge: edge,
                cornerRadius: cornerRadius,
                padding: padding
            )
        )
    }

    /// The hover chip of a glyph-only icon control, its glyph in
    /// `ink2` (#1393; the accent is a control FILL's). At a row's end
    /// it rests at nothing, the row framing it; `resting` keeps the
    /// rest fill for a glyph standing alone beside text, which
    /// nothing else marks as a button.
    func iconHoverChip(
        resting: Bool = false,
        cornerRadius: CGFloat = 4,
        padding: CGFloat = 2
    ) -> some View {
        tint(SettingsTheme.ink2)
            .hoverHighlight(
                rest: resting ? SettingsTheme.chipRest : .clear,
                hover: SettingsTheme.chipHover,
                edge: nil,
                cornerRadius: cornerRadius,
                padding: padding
            )
    }

    /// Complete affordance for icon buttons with hover chip, tooltip, and
    /// accessibility label.
    func iconButtonAffordance(
        _ label: String,
        resting: Bool = false,
        cornerRadius: CGFloat = 4,
        padding: CGFloat = 2
    ) -> some View {
        iconHoverChip(
            resting: resting,
            cornerRadius: cornerRadius,
            padding: padding
        )
        .help(label)
        .accessibilityLabel(label)
    }

    /// Hover highlight for full-width row buttons starting with transparent
    /// rest state (#956).
    func rowHoverHighlight(
        cornerRadius: CGFloat = 5,
        padding: CGFloat = 0
    ) -> some View {
        hoverHighlight(
            rest: .clear,
            hover: Color.primary.opacity(0.06),
            edge: nil,
            cornerRadius: cornerRadius,
            padding: padding
        )
    }
}
