import KiwiDeskCore
import SwiftUI

/// Custom arbitrary Lua keybinding management group (#68 §3.6.1).
/// Raw Lua stays monospaced on purpose: arbitrary Lua IS the
/// capability, not a serialization leak. A row names itself and its
/// keys on its first line and carries its symbol, Lua and shortcut
/// group on its second (#2544 ▸ Ruling).
struct AdvancedLuaGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.disabledSystemShortcuts)
    var disabledSystemShortcuts
    @Environment(\.keybindingLayerName)
    var layerName
    @State var editing: LuaEditRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($bindings) { $binding in
                if binding.kind == .custom {
                    row($binding)
                }
            }
            Button {
                bindings.append(KeyBinding(kind: .custom))
            } label: {
                Label(
                    L("shortcuts.add_binding", "Add binding"),
                    systemImage: "plus"
                )
            }
            .settingsActionButton()
        }
    }

    func record(
        _ combo: String,
        into binding: Binding<KeyBinding>
    ) {
        binding.wrappedValue.combo = combo
        let id = binding.wrappedValue.id
        if let index = bindings.firstIndex(
            where: { $0.id == id }
        ) {
            model.noteRecordedCombo(
                bindings[index],
                in: bindings
            )
        }
    }

    /// Looks the row up by id at write time — safe after any
    /// structural mutation of the bindings array.
    func record(
        _ combo: String,
        id: UUID
    ) {
        guard
            let index = bindings.firstIndex(where: {
                $0.id == id
            })
        else { return }
        bindings[index].combo = combo
        model.noteRecordedCombo(
            bindings[index],
            in: bindings
        )
    }

    /// Writes an edited Lua body into the row, found by id.
    func writeLua(_ lua: String, id: UUID) {
        guard let index = bindings.firstIndex(where: { $0.id == id })
        else { return }
        bindings[index].lua = lua
    }

    /// Removes the row from the draft.
    func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }

    /// The groups bindings make of their own: the installed ones in
    /// KiwiHub's order, then any only this draft names.
    func groupsInUse() -> [String] {
        ShortcutGroup.custom(
            in: model.core.customShortcutGroups()
                + model.config.layers.flatMap(\.bindings).map(\.group)
        )
    }
}
