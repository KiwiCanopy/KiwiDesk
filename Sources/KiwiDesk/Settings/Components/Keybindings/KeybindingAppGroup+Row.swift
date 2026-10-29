import KiwiDeskCore
import SwiftUI

/// Application shortcut row component (`KeybindingAppGroup`, `KeyBinding`).
extension ApplicationsGroup {
    /// The app is fixed once added, as on an App Rules row
    /// (#2708): another app is a new row from the add picker.
    func row(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        HStack {
            HStack(spacing: 6) {
                identity(binding.wrappedValue)
                actionMenu(binding)
            }
            Spacer()
            if drawsReach {
                KeyReachColumn(
                    model: model,
                    layer: layerName,
                    binding: binding.wrappedValue
                )
            }
            KeyRecorderField(
                name: recorderName(binding.wrappedValue),
                combo: binding.wrappedValue.combo,
                reading: ConflictText.reading(
                    for: binding.wrappedValue,
                    in: bindings,
                    config: model.config,
                    disabled: disabledSystemShortcuts,
                    sides: model.appWide.modifierSides
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

    /// The App Rules icon and name; a binding whose Lua names
    /// no bundle keeps the icon slot, so its menu still lines up.
    private func identity(_ binding: KeyBinding) -> some View {
        AppRuleIdentity(
            app: KeybindingCatalog.appBundleID(from: binding.lua) ?? "",
            name: appName(binding)
        )
    }

    /// The one name the row both draws and speaks: the stored
    /// label, else the bundle's.
    private func appName(_ binding: KeyBinding) -> String {
        if !binding.label.isEmpty { return binding.label }
        return KeybindingCatalog.appBundleID(from: binding.lua).map {
            KeybindingCatalog.displayName(forBundleID: $0)
        } ?? ""
    }

    /// The recorder is the row's one control naming what it binds,
    /// and an app may hold a row per action.
    private func recorderName(_ binding: KeyBinding) -> String {
        let action =
            KeybindingCatalog.appShortcutAction(from: binding.lua)
            ?? .openOrFocus
        return L(
            "shortcuts.apps.recorder_name",
            "%1$@, %2$@",
            appName(binding),
            actionLabel(action)
        )
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

    /// Records shortcut combo lookup by ID (`UUID`).
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
}
