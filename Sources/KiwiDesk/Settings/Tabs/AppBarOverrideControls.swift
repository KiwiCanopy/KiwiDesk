import KiwiDeskCore
import SwiftUI

/// The Position/Style/Active-item/Content dropdown labels are
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
private struct OverrideChrome<Content: View>: View {
    let isOn: Binding<Bool>
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: SettingsMetrics.overrideRowInset) {
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
                .opacity(isOn.wrappedValue ? 1 : 0.5)
                // The narrowed column pays for the checkbox
                // prefix, so the shared rows inside land on
                // the same control axis as plain rows.
                .environment(
                    \.settingsLabelColumn,
                    SettingsMetrics.overrideLabelColumn
                )
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
private func overrideToggle<T: Sendable>(
    _ value: Binding<T?>,
    global: T
) -> Binding<Bool> {
    Binding(
        get: { value.wrappedValue != nil },
        set: { value.wrappedValue = $0 ? global : nil }
    )
}

private func overrideValue<T: Sendable>(
    _ value: Binding<T?>,
    global: T
) -> Binding<T> {
    Binding(
        get: { value.wrappedValue ?? global },
        set: { value.wrappedValue = $0 }
    )
}

struct OverrideSliderRow: View {
    let label: String
    @Binding var value: CGFloat?
    let global: CGFloat
    var range: ClosedRange<Double> = 0...100

    var body: some View {
        OverrideChrome(isOn: overrideToggle($value, global: global)) {
            PtSlider(
                label: label,
                value: overrideValue($value, global: global),
                range: range
            )
        }
    }
}

struct OverrideColorRow: View {
    let label: String
    @Binding var value: String?
    let global: String

    var body: some View {
        OverrideChrome(isOn: overrideToggle($value, global: global)) {
            HexColorField(
                label: label,
                hex: overrideValue($value, global: global)
            )
        }
    }
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

    var body: some View {
        OverrideChrome(isOn: overrideToggle($value, global: global)) {
            RatioRow(
                label: label,
                value: overrideValue($value, global: global)
            )
        }
    }
}

/// An override picker over any labeled, hashable option set.
struct OverridePickerRow<Value: Hashable & Sendable>: View {
    let label: String
    @Binding var value: Value?
    let global: Value
    let options: [(Value, String)]

    var body: some View {
        OverrideChrome(isOn: overrideToggle($value, global: global)) {
            DropdownRow(label: label) {
                Picker(
                    label,
                    selection: overrideValue(
                        $value,
                        global: global
                    )
                ) {
                    ForEach(options, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }
            }
        }
    }
}

/// The shared option lists so the global editor and the
/// per-layout override pickers stay in sync.
enum AppBarOptions {
    @MainActor
    static let position: [(AppBarStyle.Position, String)] = [
        (.top, L("app_bar.position.top", "Top")),
        (.bottom, L("app_bar.position.bottom", "Bottom")),
        (.left, L("app_bar.position.left", "Left")),
        (.right, L("app_bar.position.right", "Right")),
    ]
    @MainActor
    static let style: [(AppBarStyle.Style, String)] = [
        (.pills, L("app_bar.style.pills", "Pills")),
        (.segments, L("app_bar.style.segments", "Segments")),
        (.underline, L("app_bar.style.underline", "Underline")),
    ]
    @MainActor
    static let activeStyle: [(AppBarStyle.ActiveStyle, String)] =
        [
            (
                .highlight,
                L("app_bar.active_style.highlight", "Highlight")
            ),
            (.gap, L("app_bar.active_style.gap", "Gap")),
        ]
    @MainActor
    static let content: [(AppBarStyle.Content, String)] = [
        (.icon, L("app_bar.content.icon", "Icon")),
        (.name, L("app_bar.content.name", "Name")),
        (
            .iconAndName,
            L("app_bar.content.icon_and_name", "Icon & name")
        ),
    ]
}
