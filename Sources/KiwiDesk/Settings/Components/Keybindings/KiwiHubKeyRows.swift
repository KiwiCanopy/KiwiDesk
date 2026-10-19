import KiwiDeskCore
import SwiftUI

/// KiwiHub's rows in the Show & hide card (#2265): one panel, its
/// sides in the order of their keys, J K L.
struct KiwiHubKeyRows: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        ForEach(ShortcutsRowOrder.kiwiHubAtRest, id: \.id) { key in
            anchored(key) {
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
        }
    }

    /// The shortcuts-panel row carries its catalog anchor (#277,
    /// #1520) in ONE view, as `KiwiDeskKeyRows` does; the two
    /// other sides' labels are dynamic and take none.
    @ViewBuilder private func anchored<Family: View>(
        _ key: SettingKey,
        @ViewBuilder family: () -> Family
    ) -> some View {
        if key == .shortcuts(.showShortcuts) {
            VStack(alignment: .leading, spacing: 8) { family() }
                .searchAnchored(
                    SettingsCatalog.shortcuts.showShortcutsBinding
                )
        } else {
            family()
        }
    }
}
