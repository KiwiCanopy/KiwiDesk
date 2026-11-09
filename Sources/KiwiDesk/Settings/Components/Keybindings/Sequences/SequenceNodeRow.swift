import KiwiDeskCore
import SwiftUI

/// One node of a key sequence's outline (#1871 ▸ Settings): the
/// leader or a key that opens more keys — a disclosure, a name and
/// its key count — or an end key with its action pop-up; each with
/// its recorder and trash. An open branch draws its keys indented
/// behind a 1 pt rail that runs down to its "Add Key".
struct SequenceNodeRow: View {
    @ObservedObject var model: SettingsModel
    let editing: SequenceEditing
    let node: KeyBinding
    let catalog: SequenceActionCatalog
    @Binding var collapsed: Set<UUID>
    /// The node just added, whose recorder arms on arrival.
    @Binding var fresh: UUID?
    @Environment(\.disabledSystemShortcuts)
    var disabledSystemShortcuts
    @State private var confirmingDelete = false
    @State private var editingLua: LuaEditRequest?

    var isLeader: Bool { node.id == editing.rootID }
    private var isOpen: Bool { !collapsed.contains(node.id) }
    var name: String {
        SequenceNames.name(of: node, catalog: catalog, config: model.config)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if node.isSequence { branchLine } else { endKeyLine }
                Spacer(minLength: 8)
                recorder
                AppRuleDeleteButton(
                    help: L("shortcuts.sequence.remove", "Remove key"),
                    sharedFrom: nil
                ) { _ in requestDelete() }
            }
            if node.isSequence, node.steps?.isEmpty ?? true {
                Text(L("shortcuts.sequence.empty", "Does nothing yet"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, SettingsMetrics.shortcutIconSlot + 8)
            }
            if node.isSequence, isOpen { keys }
        }
        .id(node.id.uuidString)
        .confirmationDialog(
            L(
                "shortcuts.sequence.delete_title",
                "Remove \u{201C}%1$@\u{201D} and every key under it?",
                name
            ),
            isPresented: $confirmingDelete
        ) {
            Button(
                L("shortcuts.sequence.delete_confirm", "Remove"),
                role: .destructive
            ) { editing.remove(node.id) }
        }
    }

    // MARK: - Lines

    private var branchLine: some View {
        HStack(spacing: 8) {
            Button {
                if isOpen {
                    collapsed.insert(node.id)
                } else {
                    collapsed.remove(node.id)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
                    .frame(width: SettingsMetrics.shortcutIconSlot)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(SettingsTheme.ink2)
            .accessibilityLabel(name)
            .accessibilityValue(
                isOpen
                    ? L("settings.disclosure.ax_expanded", "expanded")
                    : L("settings.disclosure.ax_collapsed", "collapsed")
            )
            TextField(
                L("shortcuts.sequence.name", "Name"),
                text: editing.field(node.id, \.label)
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 180)
            .accessibilityLabel(
                nameLabel
            )
            Text(
                L(
                    "shortcuts.sequence.key_count",
                    "Keys: %1$d",
                    node.steps?.count ?? 0
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var endKeyLine: some View {
        HStack(spacing: 8) {
            Color.clear
                .frame(width: SettingsMetrics.shortcutIconSlot)
                .overlay { glyph }
            SequenceActionMenu(
                node: node,
                catalog: catalog,
                spokenLabel: actionLabel,
                onBranch: {
                    editing.update(node.id) { $0 = SequenceTree.branch($0) }
                },
                onPick: { command in
                    editing.update(node.id) {
                        $0 = SequenceTree.endKey($0, running: command)
                    }
                },
                onLua: {
                    editing.update(node.id) { $0 = SequenceTree.luaKey($0) }
                    editingLua = LuaEditRequest(id: node.id)
                }
            )
            if node.kind == .custom { luaFields }
        }
    }

    @ViewBuilder private var glyph: some View {
        if node.kind == .custom {
            IconGlyphLabel(icon: LuaMark.symbol)
        } else if let command = catalog.command(running: node.lua),
            let icon = ShortcutsReferenceBuilder.icon(for: command)
        {
            IconGlyphLabel(icon: icon)
        }
    }

    /// A Lua end key's Description, named in the hint panel, and the
    /// button opening its body in the Lua bindings drawer's editor.
    private var luaFields: some View {
        HStack(spacing: 6) {
            TextField(
                L("shortcuts.lua.desc_placeholder", "Description"),
                text: editing.field(node.id, \.desc)
            )
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 200)
            .accessibilityLabel(
                L("shortcuts.lua.desc_ax", "Description for %1$@", name)
            )
            let help = L("shortcuts.lua.edit_ax", "Edit Lua for %1$@", name)
            Button {
                editingLua = LuaEditRequest(id: node.id)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .iconHoverChip()
            .foregroundStyle(SettingsTheme.ink2)
            .help(help)
            .accessibilityLabel(help)
            .popover(item: $editingLua) { _ in
                LuaBindingEditor(
                    title: AdvancedLuaGroup.editorTitle(node),
                    spokenName: L(
                        "shortcuts.lua.body_ax",
                        "Lua for %1$@",
                        name
                    ),
                    placeholder: L(
                        "shortcuts.lua_placeholder",
                        "Lua, e.g. KiwiDesk.reload_config()"
                    ),
                    text: editing.field(node.id, \.lua),
                    dismiss: { editingLua = nil }
                )
                .settingsPopoverChrome()
            }
        }
    }

    // MARK: - Keys under a branch

    private var keys: some View {
        HStack(alignment: .top, spacing: 0) {
            SettingsTheme.hairline
                .frame(width: 1)
                .padding(.leading, SettingsMetrics.shortcutIconSlot / 2)
                .padding(.trailing, SettingsMetrics.shortcutIconSlot / 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(node.steps ?? []) { step in
                    SequenceNodeRow(
                        model: model,
                        editing: editing,
                        node: step,
                        catalog: catalog,
                        collapsed: $collapsed,
                        fresh: $fresh
                    )
                }
                Button {
                    let key = SequenceTree.newEndKey()
                    editing.edit {
                        SequenceTree.appending(key, to: node.id, in: $0)
                    }
                    fresh = key.id
                } label: {
                    Label(
                        L("shortcuts.sequence.add_key", "Add Key"),
                        systemImage: "plus"
                    )
                }
                .settingsActionButton()
                .accessibilityHint(name)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
    }

    private func requestDelete() {
        if node.isSequence, !(node.steps?.isEmpty ?? true) {
            confirmingDelete = true
        } else {
            editing.remove(node.id)
        }
    }
}
