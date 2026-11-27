import SwiftUI

extension View {
    /// The opaque ground a control on the update window's glass
    /// sits on (#3666): the glass adapts to the backdrop, so a
    /// fixed ink on a translucent face sinks wherever it greys.
    /// On `card` the control's face and ink are the ones
    /// `SettingsThemeContrastTests` measures there. Updates-only
    /// until a second glass surface needs it (#3666 ruling).
    func updateControlGround<S: Shape>(_ shape: S) -> some View {
        background { shape.fill(SettingsTheme.card) }
    }

    /// An action button's ground, in its chip's own shape at the
    /// environment's control size. Follows `settingsActionButton()`.
    func updateActionGround() -> some View {
        modifier(UpdateActionGround())
    }
}

private struct UpdateActionGround: ViewModifier {
    @Environment(\.controlSize) private var controlSize

    func body(content: Content) -> some View {
        content.updateControlGround(
            RoundedRectangle(
                cornerRadius: ButtonChipStyle.metrics(for: controlSize)
                    .radius,
                style: .continuous
            )
        )
    }
}

/// A pop-up on the update window's glass (#3666 ruling): a `Menu`
/// holding the inline `Picker`, its trigger the pop-up seal's
/// capsule on the opaque ground. A native `.menu` picker's bezel
/// adapts with the glass and its label does not.
struct UpdatePopUp<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let options: [(title: String, value: Value)]

    var body: some View {
        Menu {
            Picker(label, selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(SettingsTheme.ink2)
            }
        }
        // The button style draws the label whole, as the profile
        // chip's does; the seal makes the capsule the hit area.
        .menuStyle(.button)
        .settingsPopUpTrigger()
        .neutralMenuLabel()
        .menuIndicator(.hidden)
        .updateControlGround(Capsule())
        .fixedSize()
        .accessibilityLabel(label)
        .accessibilityValue(title)
    }

    private var title: String {
        options.first { $0.value == selection }?.title ?? ""
    }
}
