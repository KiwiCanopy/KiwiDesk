import KiwiDeskCore
import SwiftUI

/// The Show & hide card: what the panels, the bars and KiwiVision
/// put on screen, one card named by its job with each product a
/// sub-group. KiwiVision is last because it grows a row per lens
/// (`docs/design-decisions.md` ▸ Shortcuts).
struct ShowHideGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.showHideKeys) {
            heading(SettingsCatalog.shortcuts.kiwiHubKeys)
                .searchAnchored(SettingsCatalog.shortcuts.kiwiHubKeys)
            KiwiHubKeyRows(
                model: model,
                bindings: $bindings,
                expander: expander
            )
            heading(SettingsCatalog.shortcuts.kiwishelfKeys, follows: true)
                .searchAnchored(SettingsCatalog.shortcuts.kiwishelfKeys)
            KiwiShelfKeyRows(
                model: model,
                bindings: $bindings,
                expander: expander
            )
            heading(SettingsCatalog.shortcuts.kiwiVisionKeys, follows: true)
                .searchAnchored(SettingsCatalog.shortcuts.kiwiVisionKeys)
            KiwiVisionKeyRows(
                model: model,
                bindings: $bindings,
                expander: expander
            )
        }
    }

    /// A sub-group's product name; each mount anchors its search
    /// landing at the call, where the catalog scan counts it.
    private func heading(
        _ control: SettingsControl,
        follows: Bool = false
    ) -> some View {
        SettingsGroupHeading(title: control.text, followsGroup: follows)
    }
}
