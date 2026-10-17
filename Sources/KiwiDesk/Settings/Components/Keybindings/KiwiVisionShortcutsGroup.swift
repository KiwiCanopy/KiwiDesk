import KiwiDeskCore
import SwiftUI

/// KiwiVision's shortcut section (#2312): its toggle and each
/// lens's (#2103 ruling 42). A view mode is no Focus verb, so it
/// leaves that group.
struct KiwiVisionShortcutsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.kiwiVisionKeys) {
            ForEach(ShortcutsRowOrder.kiwiVisionAtRest, id: \.id) {
                key in
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
