import KiwiDeskCore
import SwiftUI

/// KiwiVision's shortcut section (#2312): its toggle, and with
/// #2103 v3 each lens's. A view mode is no Focus verb, so it
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
