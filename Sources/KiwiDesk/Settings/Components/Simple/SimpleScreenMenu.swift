import KiwiDeskCore
import SwiftUI

/// A Space's Screen menu on Simple (#2737 ruling 4): Automatic,
/// Follows main screen, then each connected screen — the
/// placement Screens' chip writes, through the one door
/// (`SettingsModel.place`). A pin to a screen that is not
/// connected stays the selection; the row's chip says it is
/// offline.
struct SimpleScreenMenu: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID

    var body: some View {
        let hint = L("simple.space.screen.help", "Screen for this Space")
        Picker("", selection: binding) {
            Text(L("monitor_chip.automatic", "Automatic"))
                .tag(SpaceScreenChoice.auto)
            Text(L("monitor_card.follows_main", "Follows main screen"))
                .tag(SpaceScreenChoice.followsMain)
            Divider()
            ForEach(model.displays, id: \.fingerprint) { display in
                Text(display.name)
                    .tag(SpaceScreenChoice.screen(display.fingerprint))
            }
            if let offline = offlinePin {
                Text(model.screenName(offline))
                    .tag(SpaceScreenChoice.screen(offline))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .neutralMenuLabel()
        .controlSize(.large)
        .frame(width: 170)
        .help(hint)
        .accessibilityLabel(hint)
        .accessibilityValue(spokenValue)
    }

    /// The selection's own words; the label replaced them.
    private var spokenValue: String {
        switch model.screenChoice(of: space) {
        case .auto:
            L("monitor_chip.automatic", "Automatic")
        case .followsMain:
            L("monitor_card.follows_main", "Follows main screen")
        case .screen(let fingerprint):
            model.screenName(fingerprint)
        }
    }

    private var binding: Binding<SpaceScreenChoice> {
        Binding(
            get: { model.screenChoice(of: space) },
            set: { model.place(space, $0) }
        )
    }

    /// The pinned screen's fingerprint when it is not connected.
    private var offlinePin: String? {
        guard case .screen(let pin) = model.screenChoice(of: space),
            !model.displays.contains(where: { $0.fingerprint == pin })
        else { return nil }
        return pin
    }
}
