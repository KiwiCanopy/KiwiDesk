import KiwiDeskCore
import SwiftUI

/// Section 1 — Navigation: Focus, Window Movement, and Space
/// Movement commands grouped into dropdowns. Space rows are
/// generated from the defined spaces, so adding a space adds its
/// commands here. Recording upserts a `.navigation` row keyed by
/// its Lua; clearing removes it.
struct NavigationSection: View {
    @Binding var bindings: [KeyBinding]
    let spaces: [SpaceID]

    var body: some View {
        SettingsSection("Navigation") {
            ForEach(
                KeybindingCatalog.navigationGroups(spaces: spaces)
            ) { group in
                DisclosureGroup(group.title) {
                    ForEach(group.commands) { command in
                        NavRow(
                            bindings: $bindings,
                            command: command
                        )
                    }
                }
            }
        }
    }
}

/// Section — Change Modes: one row per other mode, binding a
/// `switch_mode` shortcut. Shown only when more than one mode
/// exists.
struct ChangeModesSection: View {
    @Binding var bindings: [KeyBinding]
    let modeNames: [String]
    let current: String

    var body: some View {
        SettingsSection("Change Modes") {
            ForEach(others, id: \.self) { name in
                NavRow(
                    bindings: $bindings,
                    command: NavCommand(
                        label: "Switch to \(name)",
                        lua: "KiwiDesk.switch_mode"
                            + "(\(KeybindingCatalog.quote(name)))"
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
    @Binding var bindings: [KeyBinding]
    let command: NavCommand

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
    }

    private var index: Int? {
        bindings.firstIndex {
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
    }

    private func clear() {
        if let index { bindings.remove(at: index) }
    }
}

/// Section 3 — Custom Bindings: inline Lua actions. Starts empty;
/// "+" appends a row.
struct CustomSection: View {
    @Binding var bindings: [KeyBinding]

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
                onRecord: { binding.wrappedValue.combo = $0 },
                onClear: { binding.wrappedValue.combo = "" }
            )
            Button {
                remove(binding.wrappedValue.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }
}
