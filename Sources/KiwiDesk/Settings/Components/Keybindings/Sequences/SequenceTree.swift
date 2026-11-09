import Foundation
import KiwiDeskCore

/// The Key sequences card's edits on one sequence's stored tree,
/// each node found by its id (#1871). A node is a `.sequence`
/// binding — a leader or a key that opens more keys — or an end
/// key; every edit keeps the decoder's pairing of the two (a
/// sequence carries `steps`, nothing else does).
enum SequenceTree {
    /// The node `id` names under `root`, `root` included.
    static func node(_ id: UUID, in root: KeyBinding) -> KeyBinding? {
        if root.id == id { return root }
        for step in root.steps ?? [] {
            if let hit = node(id, in: step) { return hit }
        }
        return nil
    }

    /// `root` with the node `id` names passed through `edit`.
    static func updating(
        _ id: UUID,
        in root: KeyBinding,
        _ edit: (inout KeyBinding) -> Void
    ) -> KeyBinding {
        var root = root
        if root.id == id {
            edit(&root)
            return root
        }
        root.steps = root.steps?.map { updating(id, in: $0, edit) }
        return root
    }

    /// `root` without the node `id` names, its keys with it.
    static func removing(_ id: UUID, from root: KeyBinding) -> KeyBinding {
        var root = root
        root.steps = root.steps?
            .filter { $0.id != id }
            .map { removing(id, from: $0) }
        return root
    }

    /// `root` with `child` appended to the keys of `parent`.
    static func appending(
        _ child: KeyBinding,
        to parent: UUID,
        in root: KeyBinding
    ) -> KeyBinding {
        updating(parent, in: root) { $0.steps?.append(child) }
    }

    /// An end key no action has been chosen for yet: the pop-up
    /// reads "Choose…" until one is.
    static func newEndKey(combo: String = "") -> KeyBinding {
        KeyBinding(combo: combo, kind: .navigation)
    }

    /// `node` turned into a key that opens more keys, named `name`:
    /// its action dropped, no keys under it yet.
    static func branch(_ node: KeyBinding, name: String = "") -> KeyBinding {
        var branch = KeyBinding.sequence(combo: node.combo, label: name)
        branch.id = node.id
        return branch
    }

    /// `node` running the catalogue's `command`, as the page's own
    /// rows store it.
    static func endKey(_ node: KeyBinding, running command: NavCommand)
        -> KeyBinding
    {
        var key = KeyBinding(
            combo: node.combo,
            lua: command.lua,
            kind: .navigation,
            label: command.label
        )
        key.id = node.id
        return key
    }

    /// `node` running the user's own Lua, kept where it already did.
    static func luaKey(_ node: KeyBinding) -> KeyBinding {
        guard node.kind != .custom else { return node }
        var key = KeyBinding(combo: node.combo, kind: .custom)
        key.id = node.id
        return key
    }

    /// The other key of `node`'s step holding `combo`, nil where
    /// none does — step keys match strictly, held modifiers
    /// included (#1871 ▸ step keys).
    static func sibling(
        holding combo: String,
        besides node: UUID,
        in root: KeyBinding
    ) -> KeyBinding? {
        guard !combo.isEmpty, let parent = parent(of: node, in: root)
        else { return nil }
        return parent.steps?.first {
            $0.id != node && !$0.combo.isEmpty
                && KeyCombo.equivalent($0.combo, combo)
        }
    }

    /// The node whose keys hold `id`, nil for `root` itself.
    static func parent(of id: UUID, in root: KeyBinding) -> KeyBinding? {
        guard let steps = root.steps else { return nil }
        if steps.contains(where: { $0.id == id }) { return root }
        for step in steps {
            if let hit = parent(of: id, in: step) { return hit }
        }
        return nil
    }
}
