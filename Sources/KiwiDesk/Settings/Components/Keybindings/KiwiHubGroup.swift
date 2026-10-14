import KiwiDeskCore
import SwiftUI

/// KiwiHub's shortcut section (#2265): one group for the one
/// panel, its sides in the order of their keys, J K L.
struct KiwiHubGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.kiwiHubKeys) {
            ForEach(ShortcutsRowOrder.kiwiHubAtRest, id: \.id) {
                key in
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
