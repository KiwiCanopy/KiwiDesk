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
                subject: subject,
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

    /// The checklist's name for the row, in the reader's language.
    var subject: String {
        KeybindingCatalog.localizedName(
            of: binding,
            config: model.config
        )
    }
}

/// The trash column's width, held empty and unannounced: the
/// shared-rule menu form, the wider of the trash's two, so a card's
/// reach and key columns line up whichever form a row draws.
struct KeyReachTrashSlot: View {
    var body: some View {
        AppRuleDeleteButton(help: "", sharedFrom: Self.menuForm) { _ in }
            .hidden()
            .accessibilityHidden(true)
    }

    private static let menuForm = RuleReachReading(
        editing: "",
        loaded: nil,
        profiles: [],
        unreadable: [],
        shared: true,
        hasShared: true,
        users: [],
        own: [:],
        ownIsShared: [],
        leftOut: []
    )
}

/// A shortcut row's trash, asking where a shared shortcut goes
/// (#1393): "Remove from <profile>" leaves that profile out and
/// keeps it for the others.
struct KeyReachTrash: View {
    @ObservedObject var model: SettingsModel
    let layer: String
    let binding: KeyBinding
    let onRemove: () -> Void

    var body: some View {
        ZStack {
            KeyReachTrashSlot()
            AppRuleDeleteButton(
                help: L("shortcuts.remove_binding", "Remove shortcut"),
                sharedFrom: sharedFrom
            ) { removal in
                model.recordRemoval(.key, key, removal)
                onRemove()
            }
        }
    }

    private var key: String {
        RuleReachTable<String>.keyID(layer: layer, lua: binding.lua)
    }

    private var sharedFrom: RuleReachReading? {
        guard model.offersReachColumn, !binding.lua.isEmpty,
            let reading = model.keyReach(key), reading.users.count > 1
        else { return nil }
        return reading
    }
}
