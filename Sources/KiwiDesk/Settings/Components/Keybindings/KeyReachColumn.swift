import KiwiDeskCore
import SwiftUI

/// A shortcut row's "Applies to" column (#1393): the App Rules
/// checklist, keyed by the row's layer and action. Drawn only for
/// a bound action, where there is a rule to reach.
///
/// It reads what it draws at init, in its parent's render, and
/// observes nothing, so a row that skips its render skips this
/// column too (#2783).
struct KeyReachColumn: View, Equatable {
    let model: SettingsModel
    let layer: String
    let binding: KeyBinding
    /// The row's checklist; nil where the column is not drawn.
    let reading: RuleReachReading?
    /// The checklist's name for the row, in the reader's language.
    let subject: String

    init(model: SettingsModel, layer: String, binding: KeyBinding) {
        self.init(
            model: model,
            layer: layer,
            binding: binding,
            reading: Self.reading(model: model, layer: layer, binding: binding)
        )
    }

    /// A column over a `reading` its row already took.
    init(
        model: SettingsModel,
        layer: String,
        binding: KeyBinding,
        reading: RuleReachReading?
    ) {
        self.model = model
        self.layer = layer
        self.binding = binding
        self.reading = reading
        subject = Self.subject(of: binding, model: model)
    }

    var body: some View {
        if let reading {
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

    /// The checklist a row's column draws: a bound action, on a
    /// page with profiles to reach.
    static func reading(
        model: SettingsModel,
        layer: String,
        binding: KeyBinding
    ) -> RuleReachReading? {
        guard model.offersReachColumn, !binding.lua.isEmpty else {
            return nil
        }
        return model.keyReach(
            RuleReachTable<String>.keyID(layer: layer, lua: binding.lua)
        )
    }

    static func subject(of binding: KeyBinding, model: SettingsModel)
        -> String
    {
        KeybindingCatalog.localizedName(
            of: binding,
            config: model.config
        )
    }

    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.model === b.model && a.layer == b.layer
            && a.binding == b.binding && a.reading == b.reading
            && a.subject == b.subject
    }
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

    private var sharedFrom: RuleReachReading? {
        guard model.offersReachColumn, !binding.lua.isEmpty,
            let reading = model.keyReach(key), reading.users.count > 1
        else { return nil }
        return reading
    }
}
