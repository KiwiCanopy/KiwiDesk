import KiwiDeskCore
import SwiftUI

/// The Shortcuts header (#68 §3.6.1): the mode strip (chips +
/// "+" popover), the Import button — placed here, visible
/// without scrolling, where the new user it serves can find it
/// — and the selected non-default mode's compact icon/delete
/// row.
struct ShortcutsHeader: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var addingMode = false
    @State private var newMode = ""
    @State private var importedNote = false
    @State private var renamingMode = false
    @State private var renameDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                modeStrip
                Spacer()
                // Import only offers itself when init.lua has
                // custom Lua (the same condition as the
                // banner): with nothing custom in the file
                // there is nothing it could find, and inside
                // the visual editor active foreign binds have
                // already forced the raw-Lua fallback anyway.
                if model.hasCustomLua,
                    !model.editingStoredProfile
                {
                    importButton
                }
            }
            Text(modesCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            if importedNote {
                Text(importedNoteText)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            selectedModeHeader
        }
    }

    private var modesCaption: String {
        L(
            "shortcuts.modes.caption",
            "Modes are alternate shortcut sets — only the "
                + "active mode's shortcuts fire. Bind a "
                + "key below to switch between them. "
                + "\u{201C}default\u{201D} is the standard "
                + "mode and is always the active one after "
                + "the app starts."
        )
    }

    private var importedNoteText: String {
        L(
            "shortcuts.imported_note",
            "Shortcuts imported — review below, then Save."
        )
    }

    // MARK: - Mode strip

    private var modeStrip: some View {
        HStack(spacing: 6) {
            ForEach(model.config.modes) { mode in
                modeChip(mode.name)
            }
            addModeChip
        }
    }

    private func modeChip(_ name: String) -> some View {
        Button {
            selected = name
        } label: {
            Text(name)
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(
                        selected == name
                            ? Color.accentColor.opacity(0.25)
                            : Color.secondary.opacity(0.12)
                    )
                )
        }
        .buttonStyle(.plain)
    }

    /// Defining a mode is rare — the "+" chip's popover
    /// replaces the old always-visible text field (§3.6.1).
    private var addModeChip: some View {
        Button {
            addingMode = true
        } label: {
            Image(systemName: "plus")
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        Color.secondary.opacity(0.12)
                    )
                )
        }
        .buttonStyle(.plain)
        .help(L("shortcuts.add_mode.help", "Add a mode"))
        .popover(isPresented: $addingMode) {
            HStack {
                TextField(modeNamePlaceholder, text: $newMode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit(addMode)
                Button(L("shortcuts.add", "Add"), action: addMode)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddMode)
            }
            .padding(10)
        }
    }

    private var modeNamePlaceholder: String {
        L("shortcuts.mode_name", "Mode name")
    }

    // MARK: - Import (#4)

    private var importButton: some View {
        Button {
            model.importCurrentShortcuts()
            if !model.config.modes.contains(where: {
                $0.name == selected
            }) {
                selected = KeyMode.defaultName
            }
            importedNote = true
        } label: {
            Label(
                L(
                    "shortcuts.import",
                    "Import from init.lua…"
                ),
                systemImage: "square.and.arrow.down"
            )
        }
        // Small: it sits inline beside the mode chips and
        // must not read as a peer tab.
        .controlSize(.small)
        .help(importHelp)
    }

    private var importHelp: String {
        L(
            "shortcuts.import.help",
            "Reads the shortcuts active in init.lua and adds "
                + "them here, matching each combo. Known "
                + "actions sort into the groups below; "
                + "anything else lands in Advanced. Review, "
                + "then Save."
        )
    }

    // MARK: - Selected-mode row

    /// A selected non-default mode gets a compact header: its
    /// menu-bar icon and Delete (base modes protected, #55).
    @ViewBuilder private var selectedModeHeader: some View {
        if selected != KeyMode.defaultName {
            HStack(spacing: 10) {
                Text(L("shortcuts.menu_bar_icon", "Menu bar icon"))
                    .foregroundStyle(.secondary)
                IconPicker(icon: iconBinding, preview: .menuBar)
                Spacer()
                if canDeleteSelected {
                    renameModeButton
                    Button(
                        L("shortcuts.delete_mode", "Delete mode"),
                        role: .destructive,
                        action: deleteMode
                    )
                } else {
                    // O4 soft: a base mode the profile
                    // doesn't mention always survives —
                    // removal is not expressible per profile
                    // (#55 phase 7).
                    Text(
                        L(
                            "shortcuts.base_mode_protected",
                            "Base modes can't be removed here"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
    }

    private var modeIndex: Int {
        model.config.modes.firstIndex {
            $0.name == selected
        } ?? 0
    }

    private var iconBinding: Binding<String> {
        Binding(
            get: {
                model.config.modes[modeIndex].icon ?? ""
            },
            set: {
                model.config.modes[modeIndex].icon =
                    $0.isEmpty ? nil : $0
            }
        )
    }

    /// Rename shares Delete's gate (base modes are protected
    /// in profile-override editing, #55). Scope: the rewrite
    /// covers THIS config's modes and switch-mode rows; a
    /// stored profile whose sparse override (`Profile.modes`)
    /// targets the old name keeps it and resurfaces it as a
    /// standalone mode — the same accepted gap Delete has
    /// (pre-release, single user; the edit here is a draft
    /// until Save, so chasing stored files at click time
    /// would desync them from an unsaved base).
    private var renameModeButton: some View {
        Button(L("shortcuts.rename_ellipsis", "Rename…")) {
            renameDraft = selected
            renamingMode = true
        }
        .popover(isPresented: $renamingMode) {
            HStack {
                TextField(modeNamePlaceholder, text: $renameDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit(renameMode)
                Button(
                    L("shortcuts.rename", "Rename"),
                    action: renameMode
                )
                .buttonStyle(.borderedProminent)
                .disabled(!canRenameMode)
            }
            .padding(10)
        }
    }

    private var canRenameMode: Bool {
        let name = renameDraft.trimmed
        return !name.isEmpty && name != selected
            && !model.config.modes.contains {
                $0.name == name
            }
    }

    private func renameMode() {
        guard canRenameMode else { return }
        let new = renameDraft.trimmed
        model.config.modes = KeybindingCatalog.renameMode(
            in: model.config.modes,
            from: selected,
            to: new
        )
        selected = new
        renamingMode = false
    }

    // MARK: - Mode mutations

    /// Live editing: any non-default mode. Override mode:
    /// only modes the PROFILE added — base modes always pass
    /// through (O4 soft), so deleting one is inexpressible.
    private var canDeleteSelected: Bool {
        guard selected != KeyMode.defaultName else {
            return false
        }
        guard let base = model.profileEditingBaseModes else {
            return true
        }
        return !base.contains { $0.name == selected }
    }

    private var canAddMode: Bool {
        let name = newMode.trimmed
        return !name.isEmpty
            && !model.config.modes.contains {
                $0.name == name
            }
    }

    private func addMode() {
        let name = newMode.trimmed
        guard canAddMode else { return }
        model.config.modes.append(KeyMode(name: name))
        selected = name
        newMode = ""
        addingMode = false
    }

    private func deleteMode() {
        guard selected != KeyMode.defaultName else { return }
        model.config.modes.removeAll {
            $0.name == selected
        }
        selected = KeyMode.defaultName
    }
}
