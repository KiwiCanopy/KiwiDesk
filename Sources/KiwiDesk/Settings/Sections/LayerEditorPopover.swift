import KiwiDeskCore
import SwiftUI

/// What ✎, + or a chip's menu asks the layer editor for (#843):
/// one request, so the popover is built from it alone.
struct LayerEditorRequest: Identifiable, Equatable {
    enum Mode: Equatable {
        case add
        case edit(String)
    }

    let id = UUID()
    let mode: Mode
    /// Rename… opens the editor with its name field focused.
    let focusesName: Bool

    var adds: Bool { mode == .add }

    var layer: String? {
        if case .edit(let name) = mode { name } else { nil }
    }
}

/// ✎'s popover (#3263): Name, Menu bar icon and Applies to, then
/// Delete Layer… and Done. Every row writes the draft; the name
/// commits on Return, Done, blur and close, a refused one stays
/// shown with its reason and is dropped on close, and Escape drops
/// an uncommitted one. A shared layer on a stored page keeps its
/// name and reach, and the stored-page sentence takes Delete's
/// place.
struct LayerEditorPopover: View {
    @ObservedObject var model: SettingsModel
    let focusesName: Bool
    let renamed: (String) -> Void
    let close: () -> Void
    let delete: (String) -> Void
    /// The layer's name as last committed.
    @State private var current: String
    @State private var name: String
    @State private var dropsName = false
    @FocusState private var nameFocused: Bool

    init(
        model: SettingsModel,
        layer: String,
        focusesName: Bool,
        renamed: @escaping (String) -> Void,
        close: @escaping () -> Void,
        delete: @escaping (String) -> Void
    ) {
        self.model = model
        self.focusesName = focusesName
        self.renamed = renamed
        self.close = close
        self.delete = delete
        _current = State(initialValue: layer)
        _name = State(initialValue: layer)
    }

    var body: some View {
        let reading = model.layerReach(current)
        let locked = model.layerLockedHere(current)
        VStack(alignment: .leading, spacing: 10) {
            LayerEditorForm.grid {
                LayerEditorForm.row(LayerEditorWords.name) {
                    nameField(locked: locked, reading: reading)
                }
                LayerEditorForm.row(LayerEditorWords.icon) {
                    IconPicker(icon: iconBinding, preview: .menuBar)
                }
                if let reading, LayerEditorForm.offersReach(reading) {
                    LayerEditorForm.row(LayerEditorWords.reach) {
                        LayerReachControl(
                            model: model,
                            layer: current,
                            reading: reading
                        )
                        .disabled(locked)
                    }
                }
            }
            Divider()
            footer(locked: locked)
        }
        .padding(12)
        .frame(width: LayerEditorForm.width, alignment: .leading)
        .onExitCommand {
            drop()
            close()
        }
        .onAppear {
            guard focusesName else { return }
            DispatchQueue.main.async { nameFocused = true }
        }
        .onDisappear {
            if !dropsName { commitName() }
        }
    }

    private func nameField(
        locked: Bool,
        reading: RuleReachReading?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(LayerEditorWords.namePlaceholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .commitsOnSave($nameFocused, commitName)
                .disabled(locked)
            if let problem = refusal {
                LayerEditorForm.caption(problem, refused: true)
            } else if name.trimmed != current, let reading,
                let notice = LayerReachWords.renameReach(reading)
            {
                LayerEditorForm.caption(notice, refused: false)
            }
        }
    }

    private func footer(locked: Bool) -> some View {
        HStack(spacing: 10) {
            if locked {
                Text(LayerReachWords.storedPage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button(LayerEditorWords.deleteLayer, role: .destructive) {
                    drop()
                    delete(current)
                }
                .buttonStyle(.bordered)
                // The window's accent tint would replace the system
                // red the role draws (#3263 amendment).
                .tint(SettingsTheme.danger)
            }
            Spacer(minLength: 8)
            Button(LayerEditorWords.done) {
                commitName()
                close()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// Drops an uncommitted name before a close, which the field's
    /// blur would otherwise commit.
    private func drop() {
        dropsName = true
        name = current
    }

    private var refusal: String? {
        let typed = name.trimmed
        guard !typed.isEmpty, typed != current else { return nil }
        return model.layerRenameRefusal(current, typed)
    }

    private var iconBinding: Binding<String> {
        Binding(
            get: {
                model.config.layers.first { $0.name == current }?.icon ?? ""
            },
            set: { icon in
                guard
                    let index = model.config.layers.firstIndex(where: {
                        $0.name == current
                    })
                else { return }
                model.config.layers[index].icon = icon.isEmpty ? nil : icon
            }
        )
    }

    /// Rename reaches every profile the reading lists (#2022); a
    /// name any of them already has is refused inline and kept on
    /// screen until it is fixed or dropped.
    private func commitName() {
        let typed = name.trimmed
        guard !dropsName, typed != current, !typed.isEmpty,
            model.layerRenameRefusal(current, typed) == nil
        else { return }
        let old = current
        model.renameLayer(old, to: typed)
        current = typed
        name = typed
        renamed(typed)
    }
}
