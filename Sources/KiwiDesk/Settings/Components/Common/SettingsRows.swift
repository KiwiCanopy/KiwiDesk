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

    var body: some View {
        SettingsRowShape {
            SettingsRowLabel(label: label, help: help)
        } control: {
            VStack(alignment: .leading, spacing: 6) {
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
                FractionChips(value: $value, label: label)
            }
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
/// would otherwise swallow.
struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool
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

/// Hover-driven background highlight modifier for borderless controls.
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
    /// Adds hover background highlight to borderless controls.
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
                restOpacity: resting ? 0.06 : 0,
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
            restOpacity: 0,
            hoverOpacity: 0.06,
            cornerRadius: cornerRadius,
            padding: padding
        )
    }
}
