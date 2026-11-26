import Foundation
import KiwiDeskCore
import SwiftUI

/// A Space's Screen menu (#2737 ruling 4): the choices Screens'
/// chip offers (`SpaceScreenChoice.offered`), written through the
/// one door (`SettingsModel.place`). A split screen's areas sit
/// under a section for that screen (#3517 ruling 11). A pin to a
/// screen that is not connected stays the selection; the row's chip
/// says it is offline. Simple's Space rows draw it.
struct SpaceScreenMenu: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID

    var body: some View {
        let hint = L("simple.space.screen.help", "Screen for this Space")
        let offered = SpaceScreenChoice.offered(for: space, in: model)
        Picker("", selection: binding) {
            ForEach(offered.filter { !$0.isArea(in: model) }, id: \.self) {
                choice in
                Text(choice.title(in: model)).tag(choice)
                    .disabled(!choice.takesPins(in: model))
            }
            ForEach(firstOfEachScreen, id: \.id) { display in
                let areas = offered.filter {
                    $0.isArea(of: display, in: model)
                }
                if !areas.isEmpty {
                    Section(model.screenLabel(display)) {
                        // The composed name, so the closed menu reads
                        // "Screen – Left", never a bare "Left".
                        ForEach(areas, id: \.self) { choice in
                            Text(choice.title(in: model)).tag(choice)
                                .disabled(!choice.takesPins(in: model))
                        }
                    }
                }
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

    /// One section per fingerprint: twins share their area keys.
    private var firstOfEachScreen: [Display] {
        var seen = Set<String>()
        return model.displays.filter { seen.insert($0.fingerprint).inserted }
    }

    private var binding: Binding<SpaceScreenChoice> {
        Binding(
            get: { model.screenChoice(of: space) },
            set: { model.place(space, $0) }
        )
    }
}

extension SpaceScreenChoice {
    /// Whether this choice is an area of a split connected screen —
    /// `display` where one is named.
    @MainActor func isArea(
        of display: Display? = nil,
        in model: SettingsModel
    ) -> Bool {
        guard case .screen(let key) = self else { return false }
        let parsed = ScreenAreaKey(parsing: key)
        return model.displays.contains {
            $0.fingerprint == parsed.fingerprint
                && (display == nil || $0.id == display?.id)
                && model.areaLabel(parsed.areaID, on: $0) != nil
        }
    }

    /// Whether placing a Space here pins it: never on a connected
    /// screen left unnumbered (#3647).
    @MainActor func takesPins(in model: SettingsModel) -> Bool {
        guard case .screen(let key) = self else { return true }
        return model.takesPins(key)
    }
}
