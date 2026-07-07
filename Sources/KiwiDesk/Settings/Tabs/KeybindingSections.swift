import KiwiDeskCore
import SwiftUI

/// Section 1 — Space/Window Management: Focus and Window
/// Management (move, resize, float) commands grouped into
/// dropdowns. Space rows are generated from the defined spaces, so
/// adding a space adds its commands here. Recording upserts a
/// `.navigation` row keyed by its Lua; clearing removes it.
struct NavigationSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let spaces: [SpaceID]

    var body: some View {
        SettingsSection("Space/Window Management") {
            ForEach(
                KeybindingCatalog.navigationGroups(spaces: spaces)
            ) { group in
                DisclosureGroup(group.title) {
                    ForEach(group.commands) { command in
                        NavRow(
                            model: model,
                            bindings: $bindings,
                            command: command
                        )
                    }
                }
            }
            Text(
                "Shrink/Enlarge only applies in the bsp, stack, "
                    + "and scrolling layouts; it is a no-op in "
                    + "monocle, grid, and floating. It nudges the "
                    + "one split/master ratio, so it has no "
                    + "separate width and height."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// Section — Change Modes: one row per other mode, binding a
/// `switch_mode` shortcut. Shown only when more than one mode
/// exists.
struct ChangeModesSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let modeNames: [String]
    let current: String

    var body: some View {
        SettingsSection("Change Modes") {
            ForEach(others, id: \.self) { name in
                NavRow(
                    model: model,
                    bindings: $bindings,
                    command: KeybindingCatalog.switchModeCommand(
                        name
                    )
                )
            }
        }
    }

    private var others: [String] {
        modeNames.filter { $0 != current }
    }
}

/// A single navigation/mode row: label plus a recorder that
/// upserts a `.navigation` binding keyed by the command's Lua.
struct NavRow: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let command: NavCommand
    @Environment(\.keybindingOverrideBase)
    private var overrideBase

    var body: some View {
        HStack {
            Text(command.label)
            Spacer()
            KeyRecorderField(
                combo: index.map { bindings[$0].combo } ?? "",
                conflict: conflict,
                onRecord: record,
                onClear: clear
            )
        }
        .keybindingRowStyle(inherited: isInherited)
    }

    private var index: Int? {
        bindings.firstIndex {
            $0.kind == .navigation && $0.lua == command.lua
        }
    }

    /// Override mode: bound-and-equal to the base row, or
    /// unbound on both sides. Always false while editing live.
    private var isInherited: Bool {
        guard let base = overrideBase else { return false }
        if let index {
            return bindings[index].isInherited(from: base)
        }
        return !base.contains {
            $0.kind == .navigation && $0.lua == command.lua
        }
    }

    private var conflict: String? {
        guard let index else { return nil }
        return KeybindingConflicts.text(
            for: bindings[index],
            in: bindings
        )
    }

    private func record(_ combo: String) {
        if let index {
            bindings[index].combo = combo
        } else {
            bindings.append(
                KeyBinding(
                    combo: combo,
                    lua: command.lua,
                    kind: .navigation,
                    label: command.label
                )
            )
        }
        if let updated = bindings.first(
            where: { $0.lua == command.lua }
        ) {
            model.noteRecordedCombo(updated, in: bindings)
        }
    }

    private func clear() {
        if let index { bindings.remove(at: index) }
    }
}

/// Section 3 — Custom Bindings: inline Lua actions. Starts empty;
/// "+" appends a row.
struct CustomSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.keybindingOverrideBase)
    private var overrideBase

    var body: some View {
        SettingsSection("Custom Bindings") {
            ForEach($bindings) { $binding in
                if binding.kind == .custom {
                    row($binding)
                }
            }
            Button {
                bindings.append(KeyBinding(kind: .custom))
            } label: {
                Label("Add binding", systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
    }

    private func row(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        HStack {
            TextField(
                "Lua, e.g. KiwiDesk.reload_config()",
                text: binding.lua
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            KeyRecorderField(
                combo: binding.wrappedValue.combo,
                conflict: KeybindingConflicts.text(
                    for: binding.wrappedValue,
                    in: bindings
                ),
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

    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }
}
