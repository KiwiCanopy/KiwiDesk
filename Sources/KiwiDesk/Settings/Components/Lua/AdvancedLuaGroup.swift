import KiwiDeskCore
import SwiftUI

/// Custom arbitrary Lua keybinding management group (#68 §3.6.1).
/// Raw Lua stays monospaced on purpose: arbitrary Lua IS the
/// capability, not a serialization leak.
struct AdvancedLuaGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.disabledSystemShortcuts)
    private var disabledSystemShortcuts
    @Environment(\.keybindingLayerName)
    private var layerName

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

    private func row(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        HStack {
            TextField(
                L(
                    "shortcuts.lua_placeholder",
                    "Lua, e.g. KiwiDesk.reload_config()"
                ),
                text: binding.lua
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            KeyReachColumn(
                model: model,
                layer: layerName,
                binding: binding.wrappedValue
            )
            KeyRecorderField(
                name: binding.wrappedValue.lua.isEmpty
                    ? L(
                        "shortcuts.lua_placeholder",
                        "Lua, e.g. KiwiDesk.reload_config()"
                    )
                    : binding.wrappedValue.lua,
                combo: binding.wrappedValue.combo,
                reading: ConflictText.reading(
                    for: binding.wrappedValue,
                    in: bindings,
                    config: model.config,
                    disabled: disabledSystemShortcuts
                ),
                preflight: { combo in
                    RecorderPreflight.rejection(
                        combo: combo,
                        excluding: {
                            [id = binding.wrappedValue.id] in
                            $0.id == id
                        },
                        bindings: $bindings,
                        config: model.config,
                        // Id-based: Steal mutates the array
                        // (removing a navigation holder
                        // shifts indices) before committing —
                        // an element binding captured by the
                        // ForEach would write the wrong row
                        // (#68 review M2).
                        commit: {
                            record(
                                $0,
                                id: binding.wrappedValue.id
                            )
                        }
                    )
                },
                onRecord: { record($0, into: binding) },
                onClear: {
                    binding.wrappedValue.combo = ""
                }
            )
            KeyReachTrash(
                model: model,
                layer: layerName,
                binding: binding.wrappedValue
            ) { remove(binding.wrappedValue.id) }
        }
        .id(binding.wrappedValue.id.uuidString)
    }

    private func record(
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
    private func record(
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

    /// Removes the row from the draft.
    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }
}
