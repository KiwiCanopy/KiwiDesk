import KiwiDeskCore
import SwiftUI

/// One sequence of the edited layer, written through the layer's
/// rows (#1871). The sequence is found by its leader's id at each
/// read and write, so a row that outlives a reorder writes the
/// right one.
struct SequenceEditing {
    let bindings: Binding<[KeyBinding]>
    let rootID: UUID

    var rows: [KeyBinding] { bindings.wrappedValue }

    var root: KeyBinding? { rows.first { $0.id == rootID } }

    /// Rewrites the sequence through `edit`.
    func edit(_ edit: (KeyBinding) -> KeyBinding) {
        guard let at = rows.firstIndex(where: { $0.id == rootID }) else {
            return
        }
        bindings.wrappedValue[at] = edit(bindings.wrappedValue[at])
    }

    /// Rewrites the node `id` names.
    func update(_ id: UUID, _ change: (inout KeyBinding) -> Void) {
        edit { SequenceTree.updating(id, in: $0, change) }
    }

    /// Removes the node `id` names; the leader's id removes the
    /// whole sequence.
    func remove(_ id: UUID) {
        guard id != rootID else {
            bindings.wrappedValue.removeAll { $0.id == rootID }
            return
        }
        edit { SequenceTree.removing(id, from: $0) }
    }

    /// A text field's binding on one field of the node `id` names.
    func field(
        _ id: UUID,
        _ path: WritableKeyPath<KeyBinding, String> & Sendable
    ) -> Binding<String> {
        Binding(
            get: {
                root.flatMap { SequenceTree.node(id, in: $0) }?[keyPath: path]
                    ?? ""
            },
            set: { value in update(id) { $0[keyPath: path] = value } }
        )
    }
}

/// What the card calls a node wherever it names one.
@MainActor
enum SequenceNames {
    static func name(
        of node: KeyBinding,
        catalog: SequenceActionCatalog,
        config: GuiConfig
    ) -> String {
        if node.isSequence {
            return KeybindingCatalog.localizedName(of: node, config: config)
        }
        if node.kind == .custom {
            return node.desc.trimmed.isEmpty
                ? L("shortcuts.lua.new_binding", "New binding") : node.desc
        }
        if let command = catalog.command(running: node.lua) {
            return command.resolvedLabel
        }
        if !node.lua.isEmpty {
            return KeybindingCatalog.localizedName(of: node, config: config)
        }
        return L("shortcuts.sequence.new_key", "New key")
    }
}
