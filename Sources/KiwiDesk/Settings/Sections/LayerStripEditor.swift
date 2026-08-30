import KiwiDeskCore
import SwiftUI

/// Shortcut layers chip strip, add popover, and layer management actions.
struct LayerStripEditor: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var addingLayer = false
    @State private var newLayer = ""
    @State private var renameRequest: NameEditRequest?
    @State private var addLayerHovered = false
    /// Keyboard focus target following layer deletion (#816).
    @FocusState private var focusedChip: String?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            layerStrip
            Text(layersCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
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
        .focused($focusedChip, equals: name)
    }

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
        .accessibilityLabel(
            L("shortcuts.add_layer.help", "Add a layer")
        )
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

    /// Header controls for selected custom layer (base layers protected, #55).
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
                    .buttonStyle(.bordered)
                } else {
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

    /// Layer rename button (#55, #843).
    private var renameLayerButton: some View {
        Button(L("shortcuts.rename_ellipsis", "Rename…")) {
            renameRequest = NameEditRequest(
                seed: selected,
                subject: selected
            )
        }
        .settingsActionButton()
        .popover(item: $renameRequest) { request in
            NameEditPopover(
                seed: request.seed,
                placeholder: layerNamePlaceholder,
                width: 140,
                confirmLabel: { _ in
                    L("shortcuts.rename", "Rename")
                },
                isValid: { canRenameLayer($0) }
            ) { draft in
                renameLayer(draft)
            }
        }
    }

    private func canRenameLayer(_ typed: String) -> Bool {
        let name = typed.trimmed
        return !name.isEmpty && name != selected
            && !model.config.layers.contains {
                $0.name == name
            }
    }

    private func renameLayer(_ typed: String) {
        guard canRenameLayer(typed) else { return }
        let new = typed.trimmed
        model.config.layers = KeybindingCatalog.renameLayer(
            in: model.config.layers,
            from: selected,
            to: new
        )
        selected = new
        renameRequest = nil
    }

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
        // Seed default shortcuts panel keybinding for new layer (#602).
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

    /// Focus follows selection or clears if card disappears (#816, code review
    /// 2026-08-12).
    private func deleteLayer() {
        guard selected != KeyLayer.defaultName else { return }
        model.config.layers.removeAll {
            $0.name == selected
        }
        selected = KeyLayer.defaultName
        focusedChip =
            stripSurvivesDeletion
            ? KeyLayer.defaultName : nil
    }

    private var stripSurvivesDeletion: Bool {
        LayersCard.isOffered(
            config: model.config,
            mode: model.settingsMode
        )
    }
}
