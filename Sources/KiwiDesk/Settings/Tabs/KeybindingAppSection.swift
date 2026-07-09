import AppKit
import KiwiDeskCore
import SwiftUI

/// Section 2 — Open Applications: launch hotkeys. Each row picks
/// an installed app (or any bundle via "Other…") and records a
/// combo. The Lua action pulls the app into the current space,
/// launching it if needed.
struct ApplicationsSection: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    @Environment(\.keybindingOverrideBase)
    private var overrideBase

    var body: some View {
        SettingsSection(
            L(
                "shortcuts.section.open_applications",
                "Open Applications"
            )
        ) {
            ForEach($bindings) { $binding in
                if binding.kind == .application {
                    row($binding)
                }
            }
            Button {
                bindings.append(
                    KeyBinding(kind: .application)
                )
            } label: {
                Label(
                    L(
                        "shortcuts.add_application",
                        "Add application"
                    ),
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
            appMenu(binding)
            Spacer()
            KeyRecorderField(
                combo: binding.wrappedValue.combo,
                conflict: KeybindingConflicts.text(
                    for: binding.wrappedValue,
                    in: bindings
                ),
                preflight: { combo in
                    RecorderPreflight.rejection(
                        combo: combo,
                        excluding: {
                            [id = binding.wrappedValue.id] in
                            $0.id == id
                        },
                        bindings: $bindings,
                        // Id-based (#68 review M2): Steal
                        // mutates the array before this runs.
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

    private func appMenu(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        Menu {
            ForEach(KeybindingCatalog.installedApps, id: \.self) {
                name in
                Button(name) { assign(binding, name: name) }
            }
            Divider()
            Button(L("shortcuts.other_ellipsis", "Other…")) {
                chooseBundle(binding)
            }
        } label: {
            HStack(spacing: 4) {
                Text(
                    binding.wrappedValue.label.isEmpty
                        ? L(
                            "shortcuts.choose_app",
                            "Choose app…"
                        )
                        : binding.wrappedValue.label
                )
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 160, alignment: .leading)
        }
        .frame(width: 200)
    }

    private func assign(
        _ binding: Binding<KeyBinding>,
        name: String
    ) {
        binding.wrappedValue.label = name
        binding.wrappedValue.lua = KeybindingCatalog.appCommand(
            name
        )
    }

    private func chooseBundle(_ binding: Binding<KeyBinding>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.directoryURL = URL(
            fileURLWithPath: "/Applications"
        )
        guard panel.runModal() == .OK, let url = panel.url
        else { return }
        let name = url.deletingPathExtension()
            .lastPathComponent
        assign(binding, name: name)
    }

    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }
}
