import KiwiDeskCore
import SwiftUI

/// A shortcut row's "Applies to" column (#1393): the App Rules
/// checklist, keyed by the row's layer and action. Drawn only for
/// a bound action, where there is a rule to reach.
struct KeyReachColumn: View {
    @ObservedObject var model: SettingsModel
    let layer: String
    let binding: KeyBinding

    var body: some View {
        if model.offersReachColumn, !binding.lua.isEmpty,
            let reading = model.keyReach(key)
        {
            RuleReachControl(
                model: model,
                family: .key,
                app: key,
                subject: binding.label.isEmpty ? binding.lua : binding.label,
                reading: reading,
                value: binding.combo.isEmpty
                    ? L("app_rules.dash", "—")
                    : ShortcutsReferenceBuilder.glyphs(binding.combo)
            )
        }
    }

    var key: String {
        RuleReachTable<String>.keyID(layer: layer, lua: binding.lua)
    }
}

/// A shortcut row's trash, asking where a shared shortcut goes
/// (#1393): "Remove from <profile>" keeps it for the others, each
/// in its own file, since a profile cannot leave a shared shortcut
/// out.
struct KeyReachTrash: View {
    @ObservedObject var model: SettingsModel
    let layer: String
    let binding: KeyBinding
    let onRemove: () -> Void

    var body: some View {
        AppRuleDeleteButton(
            help: L("shortcuts.remove_binding", "Remove shortcut"),
            sharedFrom: sharedFrom
        ) { removal in
            model.recordRemoval(.key, key, removal)
            onRemove()
        }
    }

    private var key: String {
        RuleReachTable<String>.keyID(layer: layer, lua: binding.lua)
    }

    private var sharedFrom: String? {
        guard model.offersReachColumn, !binding.lua.isEmpty,
            let reading = model.keyReach(key), reading.users.count > 1
        else { return nil }
        return reading.editing
    }
}
