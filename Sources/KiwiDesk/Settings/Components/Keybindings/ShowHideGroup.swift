import KiwiDeskCore
import SwiftUI

/// The Show & hide card: what the panels, the bars and KiwiVision
/// put on screen, one card named by its job, each product a
/// sub-group drawing its own heading as `KiwiDeskKeyRows` does.
/// KiwiVision is last because it grows a row per lens
/// (`docs/design-decisions.md` ▸ Shortcuts).
struct ShowHideGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.showHideKeys) {
            KiwiHubKeyRows(
                model: model,
                bindings: $bindings,
                expander: expander
            )
            KiwiShelfKeyRows(
                model: model,
                bindings: $bindings,
                expander: expander
            )
            KiwiVisionKeyRows(
                model: model,
                bindings: $bindings,
                expander: expander
            )
        }
    }
}
