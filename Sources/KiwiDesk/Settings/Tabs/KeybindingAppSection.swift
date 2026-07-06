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

    var body: some View {
        SettingsSection("Open Applications") {
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
                Label("Add application", systemImage: "plus")
            }
            .buttonStyle(.borderless)
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

    private func appMenu(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        Menu {
            ForEach(KeybindingCatalog.installedApps, id: \.self) {
                name in
                Button(name) { assign(binding, name: name) }
            }
            Divider()
            Button("Other…") { chooseBundle(binding) }
        } label: {
            Text(
                binding.wrappedValue.label.isEmpty
                    ? "Choose app…"
                    : binding.wrappedValue.label
            )
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
