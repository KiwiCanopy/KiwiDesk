import KiwiDeskCore
import SwiftUI

/// Opens a branch key's Name and Icon popover, keyed by the node
/// (#843, #3162).
struct SequenceBranchRequest: Identifiable, Equatable {
    let id: UUID
}

/// A step key's two popovers (#3162 ▸ Ruling): a Lua key's Icon,
/// Description, Group and code with "Change action…", grown from
/// the Lua bindings' editor; a branch's Name and Icon behind its
/// tinted container.
extension SequenceNodeRow {
    /// "▾ Windows": the fold, then the name that opens the popover.
    var branchContainer: some View {
        SequenceContainerFace(face: .tinted) {
            HStack(spacing: 4) {
                disclosure(width: 12)
                    .font(.caption.weight(.semibold))
                Button {
                    editingBranch = SequenceBranchRequest(id: node.id)
                } label: {
                    branchTitle.fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(nameLabel)
                .accessibilityValue(node.label)
            }
        }
        .fixedSize()
        .popover(item: $editingBranch) { _ in
            branchPopover.settingsPopoverChrome()
        }
    }

    @ViewBuilder private var branchTitle: some View {
        if node.label.trimmed.isEmpty {
            Text(L("shortcuts.sequence.name", "Name"))
                .foregroundStyle(SettingsTheme.ink3)
        } else {
            Text(node.label)
        }
    }

    private var branchPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6)
            {
                GridRow {
                    fieldLabel(L("shortcuts.sequence.name", "Name"))
                    TextField(
                        L("shortcuts.sequence.name", "Name"),
                        text: editing.field(node.id, \.label)
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(nameLabel)
                }
                GridRow {
                    fieldLabel(Self.iconLabel)
                    ShortcutSymbolPicker.branch(
                        editing.field(node.id, \.symbol),
                        name: name
                    )
                }
            }
            HStack {
                Spacer()
                Button(L("common.done", "Done")) { editingBranch = nil }
                    .kiwiProminentButton()
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    /// The Lua editor with the key's Icon, Description and Group
    /// above its code, and "Change action…" to make it a normal key.
    var luaPopover: some View {
        LuaBindingEditor(
            title: AdvancedLuaGroup.editorTitle(node),
            spokenName: L("shortcuts.lua.body_ax", "Lua for %1$@", name),
            placeholder: L(
                "shortcuts.lua_placeholder",
                "Lua, e.g. KiwiDesk.reload_config()"
            ),
            text: editing.field(node.id, \.lua),
            changeAction: {
                editingLua = nil
                // The picker opens once this popover has gone.
                DispatchQueue.main.async {
                    picking = SequencePickRequest(id: node.id)
                }
            },
            dismiss: { editingLua = nil }
        ) {
            luaFields
        }
    }

    private var luaFields: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            GridRow {
                fieldLabel(Self.iconLabel)
                ShortcutSymbolPicker.lua(
                    editing.field(node.id, \.symbol),
                    name: name
                )
            }
            GridRow {
                fieldLabel(L("shortcuts.lua.desc_placeholder", "Description"))
                TextField(
                    L("shortcuts.lua.desc_placeholder", "Description"),
                    text: editing.field(node.id, \.desc)
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(
                    L("shortcuts.lua.desc_ax", "Description for %1$@", name)
                )
            }
            GridRow {
                fieldLabel(L("shortcuts.sequence.group", "Group"))
                ShortcutGroupField(
                    group: editing.field(node.id, \.group),
                    inUse: { model.shortcutGroupsInUse() },
                    rowName: name
                )
            }
        }
    }

    private static var iconLabel: String {
        L("shortcuts.sequence.icon", "Icon")
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(SettingsTheme.ink2)
            .gridColumnAlignment(.trailing)
            .accessibilityHidden(true)
    }
}
