import KiwiDeskCore
import SwiftUI

/// The Position/Background-style/Active-indicator/Content
/// dropdown labels are
/// data (an array of value/label pairs shared by the global and
/// per-layout override pickers), so they route through `L()` at
/// the point of construction (`@MainActor`, matching every
/// other GUI-only lookup) rather than as call-site literals.

/// Chrome wrapper providing override toggle and inherited readout styling
/// (#68, #678).
struct OverrideChrome<Content: View>: View {
    let isOn: Binding<Bool>
    /// The collapse target when inheriting; nil keeps the live
    /// control visible-but-disabled — the slot-size pair, whose
    /// value has no one-line form (#290).
    var inherited: (label: String, value: String)? = nil
    var alignment: VerticalAlignment = .center
    /// Rendered by the chrome, not the wrapped row, so it escapes
    /// the inherit-state dim — help stays clickable while the user
    /// decides whether to override (#94).
    var help: String? = nil
    var subject: String? = nil
    @ViewBuilder let content: Content
    @Environment(\.isInsideGreyOut) private var alreadyDimmed
    @Environment(\.overrideLayoutName) private var layoutName

    var body: some View {
        HStack(
            alignment: alignment,
            spacing: SettingsMetrics.overrideRowInset
        ) {
            // Fill a bounded width: a long inheriting readout
            // otherwise overflows the FIRST layout pass and
            // shoves the checkbox off the hittable edge — it then
            // silently ignored the first click.
            leadingContent
                .frame(maxWidth: .infinity, alignment: .leading)
            overrideCheckbox
        }
        .padding(.leading, SettingsMetrics.overrideRowInset)
        .padding(.trailing, SettingsMetrics.overrideRowInset)
        .padding(.vertical, 4)
        .background {
            if isOn.wrappedValue {
                RoundedRectangle(cornerRadius: 4)
                    .fill(SettingsTheme.accent.opacity(0.07))
            }
        }
        .overlay(alignment: .leading) {
            if isOn.wrappedValue {
                RoundedRectangle(cornerRadius: 1)
                    .fill(SettingsTheme.accent.opacity(0.7))
                    .frame(width: 2)
            }
        }
    }

    /// Renders active control or inherited state with help popover (#94, #520,
    /// #251).
    @ViewBuilder private var leadingContent: some View {
        if isOn.wrappedValue {
            HStack(spacing: SettingsMetrics.overrideRowInset) {
                liveControl
                helpButton
            }
        } else if let inherited {
            inheritedReadout(inherited)
        } else {
            // `alignment`, not `.center`: the multi-row slot-size
            // pair floats a centred `?` between its rows (owner,
            // on device, 2026-08-16).
            HStack(
                alignment: alignment,
                spacing: SettingsMetrics.overrideRowInset
            ) {
                liveControl
                    .disabled(true)
                    // Same single-dim rule as `GreyOut` (#520):
                    // inside a gated block this would compound
                    // to 0.25.
                    .opacity(!alreadyDimmed ? 0.5 : 1)
                    // A dim is not a sentence: this branch has no
                    // inherited value to narrate, so without the
                    // hint the row announces a disabled control
                    // and no reason at all.
                    .accessibilityHint(
                        L(
                            "space_override.off.help",
                            "Inheriting the global value"
                        )
                    )
                    .environment(\.isInsideGreyOut, true)
                helpButton
            }
        }
    }

    private var liveControl: some View {
        content
            .environment(
                \.settingsLabelColumn,
                SettingsMetrics.overrideLabelColumn
            )
    }

    @ViewBuilder private var helpButton: some View {
        if let help {
            HelpButton(explanation: help, subject: subject)
        }
    }

    /// Renders label with inherited summary string.
    private func inheritedReadout(
        _ inherited: (label: String, value: String)
    ) -> some View {
        // Through the shared shape so an inheriting row stacks
        // with its live siblings below the row breakpoint (code
        // review, 2026-08-11).
        SettingsRowShape {
            HStack(spacing: 4) {
                Text(inherited.label).lineLimit(1)
                helpButton
            }
        } control: {
            Text(
                L(
                    "space_override.inherits",
                    "follows %1$@ defaults · %2$@",
                    layoutName,
                    inherited.value
                )
            )
            .lineLimit(1)
            .truncationMode(.tail)
        }
        .environment(
            \.settingsLabelColumn,
            SettingsMetrics.overrideLabelColumn
        )
        .foregroundStyle(.secondary)
    }
}

/// Binding bridging optional override to active bool (#290).
/// Internal: `OverrideSlotSizeRow` drives the same chrome from
/// another file and must share this exact seed-on-check semantics.
func overrideToggle<T: Sendable>(
    _ value: Binding<T?>,
    global: T
) -> Binding<Bool> {
    Binding(
        get: { value.wrappedValue != nil },
        set: { value.wrappedValue = $0 ? global : nil }
    )
}

/// Binding bridging optional override to concrete value (#290).
func overrideValue<T: Sendable>(
    _ value: Binding<T?>,
    global: T
) -> Binding<T> {
    Binding(
        get: { value.wrappedValue ?? global },
        set: { value.wrappedValue = $0 }
    )
}

/// Override row for boolean settings.
struct OverrideToggleRow: View {
    let label: String
    @Binding var value: Bool?
    let global: Bool

    var body: some View {
        OverrideChrome(
            isOn: overrideToggle($value, global: global),
            inherited: (
                label,
                global
                    ? L("common.on", "on")
                    : L("common.off", "off")
            )
        ) {
            Toggle(
                label,
                isOn: overrideValue($value, global: global)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Override stepper over integer field within range.
struct OverrideStepperRow: View {
    let label: String
    @Binding var value: Int?
    let global: Int
    let range: ClosedRange<Int>

    var body: some View {
        OverrideChrome(
            isOn: overrideToggle($value, global: global),
            inherited: (label, "\(global)")
        ) {
            StepperRow(
                label: label,
                value: overrideValue($value, global: global),
                in: range
            )
        }
    }
}

/// Override ratio slider row (#94); the 0.1–0.9 range matches the
/// Lua ratio clamp, so the GUI can't store a value the setters
/// would reject.
struct OverrideFractionRow: View {
    let label: String
    @Binding var value: Double?
    let global: Double
    var help: String? = nil

    var body: some View {
        OverrideChrome(
            isOn: overrideToggle($value, global: global),
            inherited: (
                label,
                "\(Int((global * 100).rounded()))%"
            ),
            help: help,
            subject: label
        ) {
            RatioRow(
                label: label,
                value: overrideValue($value, global: global)
            )
        }
    }
}

/// Override dropdown picker row (#291, #94).
struct OverridePickerRow<Value: Hashable & Sendable>: View {
    let label: String
    @Binding var value: Value?
    let global: Value
    let options: [(Value, String)]
    var help: String? = nil

    var body: some View {
        OverrideChrome(
            isOn: overrideToggle($value, global: global),
            inherited: (
                label,
                options.first { $0.0 == global }?.1 ?? ""
            ),
            help: help,
            subject: label
        ) {
            DropdownRow(
                label: label,
                spokenValue: options.first { $0.0 == value ?? global }?
                    .1 ?? ""
            ) {
                Picker(
                    label,
                    selection: overrideValue($value, global: global)
                ) {
                    ForEach(options, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
            }
        }
    }
}
