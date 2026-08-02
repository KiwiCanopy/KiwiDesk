import KiwiDeskCore
import SwiftUI

/// The Position/Background-style/Active-indicator/Content
/// dropdown labels are
/// data (an array of value/label pairs shared by the global and
/// per-layout override pickers), so they route through `L()` at
/// the point of construction (`@MainActor`, matching every
/// other GUI-only lookup) rather than as call-site literals.

/// An override row, "visible but inherited" (#68 §3.4): the
/// leading checkbox is on when this scope overrides the field;
/// off inherits the global value, with the control disabled
/// and dimmed but still readable. Checking the box seeds the
/// override with the current global value. Explicitly
/// overridden rows carry a left accent bar and a subtle tint
/// so active overrides form a scannable boundary instead of a
/// checkerboard of enabled inputs.
struct OverrideChrome<Content: View>: View {
    let isOn: Binding<Bool>
    /// Vertical alignment of the checkbox against its wrapped
    /// content. `.center` for a single-row override (the norm);
    /// `.top` when the content is a multi-row group (the slot-size
    /// override, #290) so the checkbox reads as governing the
    /// stack from its first row rather than floating at its middle.
    var alignment: VerticalAlignment = .center
    /// Optional `?` popover (#94). Rendered by the chrome, not
    /// the wrapped row, so it escapes the inherit-state
    /// `disabled`/dim below — help must stay clickable exactly
    /// while the user decides whether to override.
    var help: String? = nil
    /// Field name for the `?`'s VoiceOver label (#251), so the
    /// rotor reads "Help: Split ratio" not a bare "Help".
    var subject: String? = nil
    @ViewBuilder let content: Content
    @Environment(\.isInsideGreyOut) private var alreadyDimmed

    var body: some View {
        HStack(
            alignment: alignment,
            spacing: SettingsMetrics.overrideRowInset
        ) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help(
                    isOn.wrappedValue
                        ? L(
                            "app_bar.override.on.help",
                            "Overriding the global value"
                        )
                        : L(
                            "app_bar.override.off.help",
                            "Inheriting the global value"
                        )
                )
            content
                .disabled(!isOn.wrappedValue)
                // Same single-dim rule as `GreyOut` (#520): an
                // inheriting row inside a gated block would
                // otherwise compound to 0.25.
                .opacity(
                    !isOn.wrappedValue && !alreadyDimmed
                        ? 0.5 : 1
                )
                .environment(
                    \.isInsideGreyOut,
                    alreadyDimmed || !isOn.wrappedValue
                )
                // The narrowed column pays for the checkbox
                // prefix, so the shared rows inside land on
                // the same control axis as plain rows.
                .environment(
                    \.settingsLabelColumn,
                    SettingsMetrics.overrideLabelColumn
                )
            if let help {
                HelpButton(explanation: help, subject: subject)
            }
        }
        // The inset keeps daylight between the 2 pt accent
        // bar and the checkbox, so the bar reads as a boundary
        // rather than part of the control. It is a shared
        // token: `overrideLabelColumn` derives from it.
        .padding(.leading, SettingsMetrics.overrideRowInset)
        .padding(.vertical, 2)
        .background {
            if isOn.wrappedValue {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.07))
            }
        }
        .overlay(alignment: .leading) {
            if isOn.wrappedValue {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: 2)
            }
        }
    }
}

/// Bindings that map an optional override field + its global
/// default onto the on/off checkbox and the concrete control.
/// Internal (not private): the multi-row slot-size override
/// (`OverrideSlotSizeRow`, #290) drives the same chrome from
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

func overrideValue<T: Sendable>(
    _ value: Binding<T?>,
    global: T
) -> Binding<T> {
    Binding(
        get: { value.wrappedValue ?? global },
        set: { value.wrappedValue = $0 }
    )
}

struct OverrideToggleRow: View {
    let label: String
    @Binding var value: Bool?
    let global: Bool

    var body: some View {
        OverrideChrome(isOn: overrideToggle($value, global: global)) {
            Toggle(
                label,
                isOn: overrideValue($value, global: global)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// An override stepper over an integer field, clamped to `range`.
struct OverrideStepperRow: View {
    let label: String
    @Binding var value: Int?
    let global: Int
    let range: ClosedRange<Int>

    var body: some View {
        OverrideChrome(isOn: overrideToggle($value, global: global)) {
            StepperRow(
                label: label,
                value: overrideValue($value, global: global),
                in: range
            )
        }
    }
}

/// An override ratio field riding `RatioRow`, whose 0.1–0.9
/// range matches the Lua ratio clamp (`parseSplitRatio` /
/// `parseMasterRatio`) so the GUI can't store a value the
/// setters would reject.
struct OverrideFractionRow: View {
    let label: String
    @Binding var value: Double?
    let global: Double
    /// Optional `?` popover (#94), rendered by the chrome so
    /// it stays clickable while the row inherits.
    var help: String? = nil

    var body: some View {
        OverrideChrome(
            isOn: overrideToggle($value, global: global),
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

/// An override picker over any labeled, hashable option set.
/// Renders a `.menu` dropdown: the per-Space popover — the one
/// override surface left since the per-layout bar overrides
/// went Lua-only (GUI_REMOVED_2026-08) — is the documented
/// compact-surface exception to the #291 segmented norm, its
/// inherit chrome already eating the width a segment row needs.
/// A future full-width override surface should restore the
/// segmented branch this had before the bars deletion.
struct OverridePickerRow<Value: Hashable & Sendable>: View {
    let label: String
    @Binding var value: Value?
    let global: Value
    let options: [(Value, String)]
    /// Optional `?` popover (#94), rendered by the chrome so
    /// it stays clickable while the row inherits.
    var help: String? = nil

    var body: some View {
        OverrideChrome(
            isOn: overrideToggle($value, global: global),
            help: help,
            subject: label
        ) {
            DropdownRow(label: label) {
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
