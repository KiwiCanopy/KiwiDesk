import KiwiDeskCore
import SwiftUI

/// A Space's Screen menu (#2737 ruling 4): the choices Screens'
/// chip offers (`SpaceScreenChoice.offered`), written through the
/// one door (`SettingsModel.place`). A pin to a screen that is not
/// connected stays the selection; the row's chip says it is
/// offline. Simple's Space rows draw it.
struct SpaceScreenMenu: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID

    var body: some View {
        let hint = L("simple.space.screen.help", "Screen for this Space")
        Picker("", selection: binding) {
            ForEach(
                SpaceScreenChoice.offered(for: space, in: model),
                id: \.self
            ) { choice in
                Text(choice.title(in: model)).tag(choice)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.large)
        .fixedSize()
        .help(hint)
        .accessibilityLabel(hint)
        .accessibilityValue(
            model.screenChoice(of: space).title(in: model)
        )
    }

    private var binding: Binding<SpaceScreenChoice> {
        Binding(
            get: { model.screenChoice(of: space) },
            set: { model.place(space, $0) }
        )
    }
}
