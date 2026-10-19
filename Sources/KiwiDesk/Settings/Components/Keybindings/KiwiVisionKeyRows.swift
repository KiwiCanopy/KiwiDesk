import KiwiDeskCore
import SwiftUI

/// KiwiVision's rows in the Show & hide card (#2312): its toggle
/// and each lens's (#2103 ruling 42). A view mode is no Focus
/// verb, so it stays out of that group.
struct KiwiVisionKeyRows: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsGroupHeading(
            title: SettingsCatalog.shortcuts.kiwiVisionKeys.text,
            followsGroup: true
        )
        .searchAnchored(SettingsCatalog.shortcuts.kiwiVisionKeys)
        ForEach(ShortcutsRowOrder.kiwiVisionAtRest, id: \.id) { key in
            KeybindingFamilyRows(
                model: model,
                bindings: $bindings,
                key: key,
                expander: expander
            )
        }
    }
}
