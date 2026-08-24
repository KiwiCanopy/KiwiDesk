import KiwiDeskCore
import SwiftUI

/// Lua bindings (#68 §3.6.1) — the old "Custom
/// Bindings", renamed and collapsed by its host. Raw Lua stays
/// monospaced on purpose: arbitrary Lua *is* the capability
/// here, not a serialization leak.
struct AdvancedLuaGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.keybindingOverrideBase)
    private var overrideBase
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
            KeyRecorderField(
                name: binding.wrappedValue.lua.isEmpty
                    ? L(
                        "shortcuts.lua_placeholder",
                        "Lua, e.g. KiwiDesk.reload_config()"
                    )
                    : binding.wrappedValue.lua,
                combo: binding.wrappedValue.combo,
                conflict: ConflictText.tooltip(
                    for: binding.wrappedValue,
                    in: bindings,
                    config: model.config
                ),
                preflight: { combo in
                    RecorderPreflight.rejection(
                        combo: combo,
                        excluding: {
                            [id = binding.wrappedValue.id] in
                            $0.id == id
                        },
                        bindings: $bindings,
                        // Id-based: Steal mutates the array
                        // (removing a navigation holder
                        // shifts indices) before committing —
                        // an element binding captured by the
                        // ForEach would write the wrong row
                        // (#68 review M2).
                        commit: {
                            _ = record(
                                $0,
                                id: binding.wrappedValue.id
                            )
                        }
                    )
                },
                onRecord: { record($0, into: binding) },
                onClear: {
                    let id = binding.wrappedValue.id
                    binding.wrappedValue.combo = ""
                    // Live target: unregister now (#123).
                    _ = model.liveApplyRecorded(
                        layerName: layerName,
                        bindingID: id,
                        combo: nil
                    )
                }
            )
            Button {
                remove(binding.wrappedValue.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L(
                    "shortcuts.remove_binding",
                    "Remove shortcut"
                )
            )
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
    ) -> LiveApplyFeedback? {
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
        return model.liveApplyRecorded(
            layerName: layerName,
            bindingID: id,
            combo: combo
        )
    }

    /// Looks the row up by id at write time — safe after any
    /// structural mutation of the bindings array.
    @discardableResult
    private func record(
        _ combo: String,
        id: UUID
    ) -> LiveApplyFeedback? {
        guard
            let index = bindings.firstIndex(where: {
                $0.id == id
            })
        else { return nil }
        bindings[index].combo = combo
        model.noteRecordedCombo(
            bindings[index],
            in: bindings
        )
        return model.liveApplyRecorded(
            layerName: layerName,
            bindingID: id,
            combo: combo
        )
    }

    /// Deleting a row must unregister its hotkey, exactly as
    /// `onClear` does above (#517). Without this the row
    /// vanishes while its shortcut keeps firing until Save or
    /// Revert — `liveApplyRecorded` rebuilds the running table
    /// from its own session copy, which never saw the removal.
    /// No-op off the live target, where nothing is registered.
    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
        _ = model.liveApplyRecorded(
            layerName: layerName,
            bindingID: id,
            combo: nil
        )
    }
}
