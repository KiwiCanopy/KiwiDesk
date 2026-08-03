import KiwiDeskCore
import SwiftUI

/// The Shortcuts header (#68 §3.6.1): the layer strip (chips +
/// "+" popover), the Import button — placed here, visible
/// without scrolling, where the new user it serves can find it
/// — and the selected non-default layer's compact icon/delete
/// row.
struct ShortcutsHeader: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var addingLayer = false
    @State private var newLayer = ""
    @State private var importedNote = false
    @State private var renamingLayer = false
    @State private var renameDraft = ""
    @State private var addLayerHovered = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                layerStrip
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
            Text(layersCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
            if importedNote {
                Text(importedNoteText)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            selectedLayerHeader
        }
        .onChange(of: isEnabled) { _, now in
            if !now { addLayerHovered = false }
        }
    }

    private var layersCaption: String {
        L(
            "shortcuts.layers.caption",
            "Layers are alternate shortcut sets — only the "
                + "active layer's shortcuts fire. Bind a "
                + "key below to switch between them. "
                + "\u{201C}default\u{201D} is the standard "
                + "layer and is always the active one after "
                + "the app starts."
        )
    }

    private var importedNoteText: String {
        L(
            "shortcuts.imported_note",
            "Shortcuts imported — review below, then Save."
        )
    }

    // MARK: - Layer strip

    private var layerStrip: some View {
        HStack(spacing: 6) {
            ForEach(model.config.layers) { layer in
                layerChip(layer.name)
            }
            addLayerChip
        }
    }

    private func layerChip(_ name: String) -> some View {
        ShortcutLayerChip(
            name: name,
            selected: selected == name
        ) {
            selected = name
        }
    }

    /// Defining a layer is rare — the "+" chip's popover
    /// replaces the old always-visible text field (§3.6.1).
    private var addLayerChip: some View {
        Button {
            addingLayer = true
        } label: {
            Image(systemName: "plus")
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        Color.secondary.opacity(
                            isEnabled && addLayerHovered
                                ? 0.18 : 0.12
                        )
                    )
                )
                .animation(hoverAnimation, value: addLayerHovered)
        }
        .buttonStyle(.plain)
        .onHover { addLayerHovered = isEnabled && $0 }
        .help(L("shortcuts.add_layer.help", "Add a layer"))
        .popover(isPresented: $addingLayer) {
            HStack {
                TextField(layerNamePlaceholder, text: $newLayer)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit(addLayer)
                Button(L("shortcuts.add", "Add"), action: addLayer)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddLayer)
            }
            .padding(10)
        }
    }

    private var layerNamePlaceholder: String {
        L("shortcuts.layer_name", "Layer name")
    }

    private var hoverAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }

    // MARK: - Import (#4)

    private var importButton: some View {
        Button {
            model.importCurrentShortcuts()
            if !model.config.layers.contains(where: {
                $0.name == selected
            }) {
                selected = KeyLayer.defaultName
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
        // Small: it sits inline beside the layer chips and
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

    // MARK: - Selected-layer row

    /// A selected non-default layer gets a compact header: its
    /// menu-bar icon and Delete (base layers protected, #55).
    @ViewBuilder private var selectedLayerHeader: some View {
        if selected != KeyLayer.defaultName {
            HStack(spacing: 10) {
                Text(L("shortcuts.menu_bar_icon", "Menu bar icon"))
                    .foregroundStyle(.secondary)
                IconPicker(icon: iconBinding, preview: .menuBar)
                Spacer()
                if canDeleteSelected {
                    renameLayerButton
                    Button(
                        L("shortcuts.delete_layer", "Delete layer"),
                        role: .destructive,
                        action: deleteLayer
                    )
                } else {
                    // O4 soft: a base layer the profile
                    // doesn't mention always survives —
                    // removal is not expressible per profile
                    // (#55 phase 7).
                    Text(
                        L(
                            "shortcuts.base_layer_protected",
                            "Base layers can't be removed here"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
    }

    private var layerIndex: Int {
        model.config.layers.firstIndex {
            $0.name == selected
        } ?? 0
    }

    private var iconBinding: Binding<String> {
        Binding(
            get: {
                model.config.layers[layerIndex].icon ?? ""
            },
            set: {
                model.config.layers[layerIndex].icon =
                    $0.isEmpty ? nil : $0
            }
        )
    }

    /// Rename shares Delete's gate (base layers are protected
    /// in profile-override editing, #55). Scope: the rewrite
    /// covers THIS config's layers and switch-layer rows; a
    /// stored profile whose sparse override (`Profile.layers`)
    /// targets the old name keeps it and resurfaces it as a
    /// standalone layer — the same accepted gap Delete has
    /// (pre-release, single user; the edit here is a draft
    /// until Save, so chasing stored files at click time
    /// would desync them from an unsaved base).
    private var renameLayerButton: some View {
        Button(L("shortcuts.rename_ellipsis", "Rename…")) {
            renameDraft = selected
            renamingLayer = true
        }
        .popover(isPresented: $renamingLayer) {
            HStack {
                TextField(layerNamePlaceholder, text: $renameDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit(renameLayer)
                Button(
                    L("shortcuts.rename", "Rename"),
                    action: renameLayer
                )
                .buttonStyle(.borderedProminent)
                .disabled(!canRenameLayer)
            }
            .padding(10)
        }
    }

    private var canRenameLayer: Bool {
        let name = renameDraft.trimmed
        return !name.isEmpty && name != selected
            && !model.config.layers.contains {
                $0.name == name
            }
    }

    private func renameLayer() {
        guard canRenameLayer else { return }
        let new = renameDraft.trimmed
        model.config.layers = KeybindingCatalog.renameLayer(
            in: model.config.layers,
            from: selected,
            to: new
        )
        selected = new
        renamingLayer = false
    }

    // MARK: - Layer mutations

    /// Live editing: any non-default layer. Override layer:
    /// only layers the PROFILE added — base layers always pass
    /// through (O4 soft), so deleting one is inexpressible.
    private var canDeleteSelected: Bool {
        guard selected != KeyLayer.defaultName else {
            return false
        }
        guard let base = model.profileEditingBaseLayers else {
            return true
        }
        return !base.contains { $0.name == selected }
    }

    private var canAddLayer: Bool {
        let name = newLayer.trimmed
        return !name.isEmpty
            && !model.config.layers.contains {
                $0.name == name
            }
    }

    private func addLayer() {
        let name = newLayer.trimmed
        guard canAddLayer else { return }
        // Seed the ⌃⌥K "Show shortcuts panel" row so a fresh layer
        // can open the cheat-sheet from the keyboard, not only via
        // the menu bar (#602). Deletable per layer like any default.
        model.config.layers.append(
            KeyLayer(
                name: name,
                bindings: [DefaultKeybindings.showShortcutsRow()]
            )
        )
        selected = name
        newLayer = ""
        addingLayer = false
    }

    private func deleteLayer() {
        guard selected != KeyLayer.defaultName else { return }
        model.config.layers.removeAll {
            $0.name == selected
        }
        selected = KeyLayer.defaultName
    }
}
