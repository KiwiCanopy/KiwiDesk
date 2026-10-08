import KiwiDeskCore
import SwiftUI

/// The selected layer's header (#55, #2022): which profiles it
/// belongs to, its menu bar icon, and Rename and Delete — which
/// ask how far they reach. `default` is protected and has none.
struct LayerHeader: View {
    @ObservedObject var model: SettingsModel
    @Binding var selected: String
    /// Runs after a delete, so the strip can place focus (#816).
    let onDeleted: () -> Void
    @State private var renameRequest: NameEditRequest?
    @State private var deleteRequest: LayerDeleteRequest?

    var body: some View {
        if selected != KeyLayer.defaultName {
            let reading = model.layerReach(selected)
            VStack(alignment: .leading, spacing: 8) {
                if let reading, offersReach(reading) {
                    // One line, as the icon line below it (owner
                    // ruling 2026-10-08): the label is drawn, the
                    // control names itself.
                    HStack(spacing: 10) {
                        Text(L("app_rules.reach", "Applies to"))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .accessibilityHidden(true)
                        Spacer(minLength: 8)
                        LayerReachControl(
                            model: model,
                            layer: selected,
                            reading: reading
                        )
                        .disabled(model.layerLockedHere(selected))
                    }
                }
                actions(reading)
            }
            .font(.callout)
            .modifier(
                LayerDeleteDialog(request: $deleteRequest, delete: delete)
            )
        }
    }

    private func actions(_ reading: RuleReachReading?) -> some View {
        HStack(spacing: 10) {
            Text(L("shortcuts.menu_bar_icon", "Menu bar icon"))
                .foregroundStyle(.secondary)
            IconPicker(icon: iconBinding, preview: .menuBar)
            Spacer()
            if model.layerLockedHere(selected) {
                Text(LayerReachWords.storedPage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                renameButton(reading)
                Button(
                    L("shortcuts.delete_layer", "Delete layer"),
                    role: .destructive
                ) {
                    requestDelete(reading)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// The row is drawn where there is a second profile to name.
    private func offersReach(_ reading: RuleReachReading) -> Bool {
        reading.profiles.count + reading.unreadable.count >= 2
    }

    private var layerIndex: Int {
        model.config.layers.firstIndex { $0.name == selected } ?? 0
    }

    private var iconBinding: Binding<String> {
        Binding(
            get: { model.config.layers[layerIndex].icon ?? "" },
            set: {
                model.config.layers[layerIndex].icon = $0.isEmpty ? nil : $0
            }
        )
    }

    /// Rename reaches every profile the reading lists (#2022), and
    /// a name any of them already has refuses it inline.
    private func renameButton(_ reading: RuleReachReading?) -> some View {
        Button(L("shortcuts.rename_ellipsis", "Rename…")) {
            renameRequest = NameEditRequest(seed: selected, subject: selected)
        }
        .settingsActionButton()
        .popover(item: $renameRequest) { request in
            NameEditPopover(
                seed: request.seed,
                placeholder: L("shortcuts.layer_name", "Layer name"),
                width: 220,
                confirmLabel: { _ in L("shortcuts.rename", "Rename") },
                isValid: { canRename($0) },
                notice: { _ in reading.flatMap(LayerReachWords.renameReach) },
                problem: { typed in
                    model.layerRenameRefusal(selected, typed.trimmed)
                }
            ) { typed in
                let new = typed.trimmed
                guard canRename(new) else { return }
                let old = selected
                renameRequest = nil
                model.renameLayer(old, to: new)
                selected = new
            }
        }
    }

    private func canRename(_ typed: String) -> Bool {
        let name = typed.trimmed
        return !name.isEmpty && name != selected
            && !model.config.layers.contains { $0.name == name }
            && model.layerRenameRefusal(selected, name) == nil
    }

    private func requestDelete(_ reading: RuleReachReading?) {
        guard model.layerDeleteAsks(selected) else {
            delete(.everywhere)
            return
        }
        deleteRequest = LayerDeleteRequest(
            layer: selected,
            count: model.layerDeleteCount(selected),
            reading: reading
        )
    }

    private func delete(_ removal: RuleRemoval) {
        model.deleteLayer(selected, removal)
        deleteRequest = nil
        onDeleted()
    }
}
