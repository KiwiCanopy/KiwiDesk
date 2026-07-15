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
    @Environment(\.keybindingModeName)
    private var modeName

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
                        modeName: modeName,
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
            modeName: modeName,
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
            modeName: modeName,
            bindingID: id,
            combo: combo
        )
    }

    private func appMenu(
        _ binding: Binding<KeyBinding>
    ) -> some View {
        AppPickerButton(
            placeholder: L(
                "shortcuts.choose_app",
                "Choose app…"
            ),
            selection: binding.wrappedValue.label.isEmpty
                ? nil
                : binding.wrappedValue.label,
            onPick: { assign(binding, app: $0) },
            escapeLabel: L("shortcuts.other_ellipsis", "Other…"),
            onEscape: { chooseBundle(binding) }
        )
        // Hug the content: the row's `Spacer()` pins the recorder
        // to the trailing edge, so the picker's width doesn't gate
        // recorder alignment — no fixed column needed.
        .fixedSize()
    }

    private func assign(
        _ binding: Binding<KeyBinding>,
        app: KeybindingCatalog.InstalledApp
    ) {
        binding.wrappedValue.label = app.name
        binding.wrappedValue.lua = KeybindingCatalog.appCommand(
            app.bundleID
        )
    }

    private func chooseBundle(_ binding: Binding<KeyBinding>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.directoryURL = URL(
            fileURLWithPath: "/Applications"
        )
        guard panel.runModal() == .OK, let url = panel.url,
            let bundleID = Bundle(url: url)?
                .bundleIdentifier?.lowercased()
        else { return }
        assign(
            binding,
            app: .init(
                bundleID: bundleID,
                name: KeybindingCatalog.displayName(
                    forBundleID: bundleID
                )
            )
        )
    }

    private func remove(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }
}
