import KiwiDeskCore
import SwiftUI

/// A per-layout override row. The leading checkbox is on when
/// this layout overrides the field; off inherits the global
/// value. The control is disabled and dimmed (gray) while
/// inheriting, editable (black) once overridden — checking the
/// box seeds the override with the current global value.
private struct OverrideChrome<Content: View>: View {
    let isOn: Binding<Bool>
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help(
                    isOn.wrappedValue
                        ? "Overriding the global value"
                        : "Inheriting the global value"
                )
            content
                .disabled(!isOn.wrappedValue)
                .opacity(isOn.wrappedValue ? 1 : 0.5)
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

/// An override picker over any labeled, hashable option set.
struct OverridePickerRow<Value: Hashable & Sendable>: View {
    let label: String
    @Binding var value: Value?
    let global: Value
    let options: [(Value, String)]

    var body: some View {
        OverrideChrome(isOn: overrideToggle($value, global: global)) {
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

/// The shared option lists so the global editor and the
/// per-layout override pickers stay in sync.
enum AppBarOptions {
    static let position: [(AppBarStyle.Position, String)] = [
        (.top, "Top"), (.bottom, "Bottom"),
        (.left, "Left"), (.right, "Right"),
    ]
    static let style: [(AppBarStyle.Style, String)] = [
        (.pills, "Pills"), (.segments, "Segments"),
        (.underline, "Underline"),
    ]
    static let activeStyle: [(AppBarStyle.ActiveStyle, String)] =
        [(.highlight, "Highlight"), (.gap, "Gap")]
    static let content: [(AppBarStyle.Content, String)] = [
        (.icon, "Icon"), (.name, "Name"),
        (.iconAndName, "Icon & name"),
    ]
}
