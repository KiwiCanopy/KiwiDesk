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
    /// Runs after Add binding appends its row, which is last.
    let onAdd: () -> Void
    @Environment(\.disabledSystemShortcuts)
    var disabledSystemShortcuts
    @Environment(\.keybindingLayerName)
    var layerName
    @State var editing: LuaEditRequest?
    @State var verdicts: [UUID: LuaVerdict] = [:]
    @FocusState var focusedLua: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach($bindings) { $binding in
                if ShortcutsGates.isLuaBinding(binding) {
                    row($binding)
                }
            }
            Button {
                bindings.append(KeyBinding(kind: .custom))
                onAdd()
            } label: {
                Label(
                    L("shortcuts.add_binding", "Add binding"),
                    systemImage: "plus"
                )
            }
            .settingsActionButton()
        }
        // An edit is judged once committed, never per keystroke
        // (#2574 ▸ Ruling): its field losing focus, its editor closing.
        .onChange(of: focusedLua) { left, _ in
            if let left { judge(left) }
        }
        .onChange(of: editing) { closed, _ in
            if let closed { judge(closed.id) }
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

    /// A row's Lua body, found by id at each read and write — the
    /// editor popover outlives no row, but the array may move.
    func luaBinding(_ id: UUID) -> Binding<String> {
        Self.luaBinding(id, in: $bindings)
    }

    static func luaBinding(
        _ id: UUID,
        in bindings: Binding<[KeyBinding]>
    ) -> Binding<String> {
        Binding(
            get: { bindings.wrappedValue.first { $0.id == id }?.lua ?? "" },
            set: { lua in
                guard
                    let index = bindings.wrappedValue.firstIndex(where: {
                        $0.id == id
                    })
                else { return }
                bindings.wrappedValue[index].lua = lua
            }
        )
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
