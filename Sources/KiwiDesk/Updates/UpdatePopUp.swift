import SwiftUI

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
