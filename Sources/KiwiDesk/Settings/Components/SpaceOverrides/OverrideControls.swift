import KiwiDeskCore
import SwiftUI

/// The Position/Background-style/Active-indicator/Content
/// dropdown labels are
/// data (an array of value/label pairs shared by the global and
/// per-layout override pickers), so they route through `L()` at
/// the point of construction (`@MainActor`, matching every
/// other GUI-only lookup) rather than as call-site literals.

/// An override row, "visible but inherited" (#68 §3.4, #678 8b
/// layout): a row overrides its field or inherits the layout's
/// default, chosen by the **OVERRIDE** checkbox in the trailing
/// column (checked = overriding). An overriding row shows its live
/// control, a left accent bar and a subtle tint, so active
/// overrides form a scannable boundary — and its checkbox is ticked,
/// agreeing with that emphasis. An inheriting row collapses its
/// control to a quiet "follows <Layout> defaults · <value>" readout
/// — the value stays visible without the control's weight.
/// The one exception is a row whose value has no one-line form (the
/// slot-size pair): it passes `inherited: nil` and keeps the live
/// control, disabled and dimmed, as before.
struct OverrideChrome<Content: View>: View {
    let isOn: Binding<Bool>
    /// The collapse target when this row inherits: its label and
    /// the inherited value's one-line form ("50%", "Horizontal").
    /// `nil` keeps the live control visible-but-disabled instead —
    /// the slot-size pair, whose value spans two controls (#290).
    var inherited: (label: String, value: String)? = nil
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
    @Environment(\.overrideLayoutName) private var layoutName

    var body: some View {
        HStack(
            alignment: alignment,
            spacing: SettingsMetrics.overrideRowInset
        ) {
            // Fill a bounded width rather than let the content take
            // its ideal: a long inheriting readout ("follows
            // <Layout> defaults · <value>") would otherwise overflow
            // the row on the FIRST layout pass and shove the trailing
            // checkbox off the hittable edge until a re-render — the
            // checkbox then silently ignored the first click (worst
            // on Scrolling, whose readout is longest).
            leadingContent
                .frame(maxWidth: .infinity, alignment: .leading)
            overrideCheckbox
        }
        // The inset keeps daylight between the 2 pt accent
        // bar and the content, so the bar reads as a boundary
        // rather than part of the control. It is a shared
        // token: `overrideLabelColumn` derives from it.
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

    /// The live control when overriding; when inheriting, either
    /// the collapsed readout (the norm) or the dimmed control (the
    /// slot-size pair, `inherited == nil`). The `?` rides alongside
    /// in every branch, so it stays clickable and label-adjacent
    /// while the user decides whether to override (#94).
    @ViewBuilder private var leadingContent: some View {
        if isOn.wrappedValue {
            HStack(spacing: SettingsMetrics.overrideRowInset) {
                liveControl
                helpButton
            }
        } else if let inherited {
            inheritedReadout(inherited)
        } else {
            // `alignment`, not the default `.center`: this branch
            // is the multi-row group (the slot-size pair), and a
            // centred `?` floats between its two rows with
            // nothing to sit beside — it read as a stray control
            // hanging in the middle of the card (owner, on
            // device, 2026-08-16). Aligned to the group's own
            // anchor it lands beside the FIRST row, which is
            // where every single-row override puts it.
            HStack(
                alignment: alignment,
                spacing: SettingsMetrics.overrideRowInset
            ) {
                liveControl
                    .disabled(true)
                    // Same single-dim rule as `GreyOut` (#520): an
                    // inheriting row inside a gated block would
                    // otherwise compound to 0.25.
                    .opacity(!alreadyDimmed ? 0.5 : 1)
                    // The dim is the only thing saying why this
                    // control is inert, and a dim is not a
                    // sentence (#678 Phase 4 pass 10, turn 20a
                    // rule 3). This is the branch with no
                    // inherited VALUE to read out — the other one
                    // already narrates through `inheritedReadout`
                    // — so without the hint the row announces a
                    // disabled control and no reason at all.
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
            // The narrowed column pays for the trailing OVERRIDE
            // column, so the shared rows inside land on the same
            // control axis as plain rows.
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

    /// `<label>    follows <Layout> defaults · <value>` — the label
    /// on the same axis a live control would use, then the `?` and
    /// the quiet readout. Secondary throughout, so an inheriting
    /// row reads as "not overriding" without an opacity that could
    /// compound.
    private func inheritedReadout(
        _ inherited: (label: String, value: String)
    ) -> some View {
        // Through the shared shape, on the override column the
        // live controls beside it use (17a): an inheriting row
        // that framed its own label kept the WIDE arrangement
        // below the row breakpoint while every live sibling in
        // the same list stacked, so one list drew two layouts
        // (code review, 2026-08-11 — the scan could not see
        // this spelling, and now does).
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

/// An override stepper over an integer field, clamped to `range`.
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

/// An override picker over any labeled, hashable option set.
/// Renders a `.menu` dropdown: the per-space override editor — the
/// one override surface left since the per-layout bar overrides
/// went Lua-only (GUI_REMOVED_2026-08) — is the documented
/// compact-surface exception to the #291 segmented norm. Its rows
/// sit in a bounded ~700 pt column with a trailing OVERRIDE
/// checkbox column, so a segmented row would be cramped and the
/// `.menu` holds (see `docs/ui-patterns.md`).
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
