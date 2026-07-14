import KiwiDeskCore
import SwiftUI

/// The GUI face of the `item_size`/`font_size` 0 = auto sentinel
/// (#228 §3): an "Auto" toggle whose on-state stores 0 and whose
/// off-state restores a sensible non-zero size, so the user never
/// drags a slider to 0 to mean "auto".
enum AppBarAuto {
    static func binding(
        _ value: Binding<CGFloat>,
        restore: CGFloat
    ) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue == 0 },
            set: { value.wrappedValue = $0 ? 0 : restore }
        )
    }
}

/// The #171 "grey, don't hide" treatment: a control that has no
/// effect in the current mode stays visible but disabled and
/// dimmed, with an optional explanatory tooltip.
struct AppBarGreyOut: ViewModifier {
    let active: Bool
    var help: String = ""

    func body(content: Content) -> some View {
        content
            .disabled(active)
            .opacity(active ? 0.5 : 1)
            .help(active ? help : "")
    }
}

/// The Position/Tab-background/Active-indicator/Content dropdown
/// labels are
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
    var unit: String = "pt"

    var body: some View {
        OverrideChrome(isOn: overrideToggle($value, global: global)) {
            PtSlider(
                label: label,
                value: overrideValue($value, global: global),
                range: range,
                unit: unit
            )
        }
    }
}

/// An override slider whose 0 = auto sentinel is exposed as an
/// Auto toggle (#228 §3), mirroring the global editor. While the
/// row overrides the field, the Auto toggle rides above the
/// slider and greys it when auto; restoring turns auto off with a
/// sensible non-zero size.
struct OverrideAutoSliderRow: View {
    let label: String
    let autoLabel: String
    @Binding var value: CGFloat?
    let global: CGFloat
    let restore: CGFloat
    var range: ClosedRange<Double> = 0...200

    var body: some View {
        OverrideChrome(isOn: overrideToggle($value, global: global)) {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(
                    autoLabel,
                    isOn: AppBarAuto.binding(
                        overrideValue($value, global: global),
                        restore: restore
                    )
                )
                PtSlider(
                    label: label,
                    value: overrideValue($value, global: global),
                    range: range
                )
                .modifier(
                    AppBarGreyOut(
                        active: (value ?? global) == 0
                    )
                )
            }
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
        (.start, L("app_bar.position.start", "Start")),
        (.end, L("app_bar.position.end", "End")),
    ]
    @MainActor
    static let tabBackground: [(AppBarStyle.TabBackground, String)] = [
        (.boxed, L("app_bar.tab_background.boxed", "Boxed")),
        (.plain, L("app_bar.tab_background.plain", "Plain")),
    ]
    @MainActor
    static let activeIndicator: [(AppBarStyle.ActiveIndicator, String)] = [
        (.ring, L("app_bar.active_indicator.ring", "Ring")),
        (
            .edgeMark,
            L(
                "app_bar.active_indicator.edge_mark",
                "Edge mark"
            )
        ),
        (.gap, L("app_bar.active_indicator.gap", "Gap")),
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
