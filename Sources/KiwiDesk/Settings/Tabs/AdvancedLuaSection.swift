import KiwiDeskCore
import SwiftUI

/// Advanced: Lua bindings (#68 §3.6.1) — the old "Custom
/// Bindings", renamed and collapsed by its host. Raw Lua stays
/// monospaced on purpose: arbitrary Lua *is* the capability
/// here, not a serialization leak.
struct AdvancedLuaSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.keybindingOverrideBase)
    private var overrideBase

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
            .buttonStyle(.bordered)
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
            KeyRecorderField(
                combo: binding.wrappedValue.combo,
                conflict: KeybindingConflicts.text(
                    for: binding.wrappedValue,
                    in: model.conflictRelevant(bindings)
                ),
                preflight: { combo in
                    RecorderPreflight.rejection(
                        combo: combo,
                        excluding: {
                            [id = binding.wrappedValue.id] in
                            $0.id == id
                        },
                        silentSteal:
                            model.isSilentlyStealable,
                        bindings: $bindings,
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
                onClear: { binding.wrappedValue.combo = "" }
            )
            Button {
                remove(binding.wrappedValue.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .keybindingRowStyle(
            inherited: binding.wrappedValue.isInherited(
                from: overrideBase
            )
        )
        .id(binding.wrappedValue.id.uuidString)
    }

    private func record(
        _ combo: String,
        into binding: Binding<KeyBinding>
    ) {
        binding.wrappedValue.combo = combo
        model.noteRecordedCombo(
            binding.wrappedValue,
            in: bindings
        )
    }

    /// Looks the row up by id at write time — safe after any
    /// structural mutation of the bindings array.
    private func record(_ combo: String, id: UUID) {
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

    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }
}
