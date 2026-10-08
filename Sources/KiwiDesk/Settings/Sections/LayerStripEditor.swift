import KiwiDeskCore
import SwiftUI

/// Shortcut layers chip strip, add popover, and layer management actions.
struct LayerStripEditor: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    @State private var addingLayer = false
    @State private var newLayer = ""
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
            LayerHeader(model: model, selected: $selected) {
                selected = KeyLayer.defaultName
                focusedChip =
                    stripSurvivesDeletion ? KeyLayer.defaultName : nil
            }
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
                .choiceChip(
                    hovering: isEnabled && addLayerHovered,
                    edged: false
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
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField(layerNamePlaceholder, text: $newLayer)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .onSubmit(addLayer)
                    Button(L("shortcuts.add", "Add"), action: addLayer)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAddLayer)
                }
                if let holder = model.layerAddClash(newLayer.trimmed) {
                    Text(LayerReachWords.clash(holder, newLayer.trimmed))
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.danger)
                        .frame(width: 220, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else if model.layerAdmission(newLayer.trimmed)
                    == .sharedElsewhere
                {
                    Text(LayerReachWords.joinOnLoadedPage)
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.danger)
                        .frame(width: 220, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else if model.layerAddRejoins(newLayer.trimmed) {
                    Text(LayerReachWords.rejoins(newLayer.trimmed))
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.ink3)
                        .frame(width: 220, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

    private var canAddLayer: Bool {
        model.canAddLayer(newLayer.trimmed)
    }

    private func addLayer() {
        let name = newLayer.trimmed
        guard model.addLayer(name) else { return }
        selected = name
        newLayer = ""
        addingLayer = false
    }

    /// Focus follows selection or clears if card disappears (#816,
    /// code review 2026-08-12).
    private var stripSurvivesDeletion: Bool {
        LayersCard.isOffered(
            config: model.config,
            mode: model.settingsMode
        )
    }
}
