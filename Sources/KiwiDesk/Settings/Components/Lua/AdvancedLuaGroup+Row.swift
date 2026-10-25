import KiwiDeskCore
import SwiftUI

/// One Lua binding's two lines (#2544 ▸ Ruling): Description, keys
/// and remove; then symbol, Lua and shortcut group. VoiceOver reads
/// the row as one binding named as KiwiHub names it.
extension AdvancedLuaGroup {
    func row(_ binding: Binding<KeyBinding>) -> some View {
        let name = rowName(binding.wrappedValue)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(
                    descPlaceholder(binding.wrappedValue),
                    text: binding.desc
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(
                    L("shortcuts.lua.desc_ax", "Description for %1$@", name)
                )
                KeyReachColumn(
                    model: model,
                    layer: layerName,
                    binding: binding.wrappedValue
                )
                recorder(binding, name: name)
                KeyReachTrash(
                    model: model,
                    layer: layerName,
                    binding: binding.wrappedValue
                ) { remove(binding.wrappedValue.id) }
            }
            HStack {
                IconPicker(
                    icon: binding.symbol,
                    preview: .chip,
                    symbolsOnly: true,
                    placeholder: LuaMark.symbol
                )
                .accessibilityLabel(
                    L("shortcuts.lua.symbol_ax", "Symbol for %1$@", name)
                )
                // `</>` is shown, never named (config-vocabulary.md).
                .accessibilityValue(
                    binding.wrappedValue.symbol.isEmpty
                        ? L("shortcuts.lua.default_symbol", "</>")
                        : binding.wrappedValue.symbol
                )
                luaLine(binding, name: name)
                ShortcutGroupField(
                    group: binding.group,
                    inUse: groupsInUse,
                    rowName: name
                )
            }
            deadWarning(binding.wrappedValue)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
        .id(binding.wrappedValue.id.uuidString)
        .onAppear { judge(binding.wrappedValue.id) }
    }

    /// The name KiwiHub lists the row under: its description, else
    /// its Lua; a row with neither is a new binding.
    func rowName(_ binding: KeyBinding) -> String {
        if !binding.desc.trimmed.isEmpty { return binding.desc }
        if !binding.lua.isEmpty { return LuaBodyShape.firstLine(binding.lua) }
        return L("shortcuts.lua.new_binding", "New binding")
    }

    private func descPlaceholder(_ binding: KeyBinding) -> String {
        binding.lua.isEmpty
            ? L("shortcuts.lua.desc_placeholder", "Description")
            : LuaBodyShape.firstLine(binding.lua)
    }

    private var luaPlaceholder: String {
        L("shortcuts.lua_placeholder", "Lua, e.g. KiwiDesk.reload_config()")
    }

    /// One line edits in place; more read as a readout that opens
    /// the editor, never a field that ignores typing.
    @ViewBuilder
    private func luaLine(
        _ binding: Binding<KeyBinding>,
        name: String
    ) -> some View {
        let lua = binding.wrappedValue.lua
        let id = binding.wrappedValue.id
        let spoken = L("shortcuts.lua.body_ax", "Lua for %1$@", name)
        Group {
            if LuaBodyShape.isMultiline(lua) {
                Button {
                    editing = LuaEditRequest(id: id)
                } label: {
                    HStack(spacing: 8) {
                        Text(LuaBodyShape.firstLine(lua))
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                        Text(
                            L(
                                "shortcuts.lua.lines",
                                "Lines: %1$d",
                                LuaBodyShape.lineCount(lua)
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.ink2)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .iconHoverChip()
                .accessibilityLabel(spoken)
                .accessibilityValue(lua)
            } else {
                TextField(luaPlaceholder, text: binding.lua)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($focusedLua, equals: id)
                    .onSubmit { judge(id) }
                    .accessibilityLabel(spoken)
            }
        }
        .frame(maxWidth: .infinity)
        expandButton(id: id, name: name)
            .popover(item: editBinding(id)) { _ in
                LuaBindingEditor(
                    title: binding.wrappedValue.desc,
                    spokenName: spoken,
                    text: luaBinding(id),
                    dismiss: { editing = nil }
                )
                .settingsPopoverChrome()
            }
    }

    private func expandButton(id: UUID, name: String) -> some View {
        let help = L("shortcuts.lua.edit_ax", "Edit Lua for %1$@", name)
        return Button {
            editing = LuaEditRequest(id: id)
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.borderless)
        .iconHoverChip()
        .foregroundStyle(SettingsTheme.ink2)
        .help(help)
        .accessibilityLabel(help)
    }

    /// The popover's item for one row: set only while that row's
    /// body is open.
    private func editBinding(_ id: UUID) -> Binding<LuaEditRequest?> {
        Binding(
            get: { editing?.id == id ? editing : nil },
            // A row's own dismissal never closes another row's.
            set: { if $0 != nil || editing?.id == id { editing = $0 } }
        )
    }

    private func recorder(
        _ binding: Binding<KeyBinding>,
        name: String
    ) -> some View {
        KeyRecorderField(
            name: name,
            combo: binding.wrappedValue.combo,
            reading: ConflictText.reading(
                for: binding.wrappedValue,
                in: bindings,
                config: model.config,
                disabled: disabledSystemShortcuts,
                sides: model.appWide.modifierSides
            ),
            preflight: { combo in
                RecorderPreflight.rejection(
                    combo: combo,
                    excluding: {
                        [id = binding.wrappedValue.id] in
                        $0.id == id
                    },
                    bindings: $bindings,
                    config: model.config,
                    // Id-based: Steal mutates the array (removing
                    // a navigation holder shifts indices) before
                    // committing — an element binding captured by
                    // the ForEach would write the wrong row (#68
                    // review M2).
                    commit: {
                        record($0, id: binding.wrappedValue.id)
                    }
                )
            },
            onRecord: { record($0, into: binding) },
            onClear: {
                binding.wrappedValue.combo = ""
            }
        )
    }
}
