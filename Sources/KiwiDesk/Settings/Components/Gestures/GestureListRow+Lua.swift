import KiwiDeskCore
import SwiftUI

/// A one-action gesture row's App… and Lua… (#3199 ▸ the action
/// picker: click, tap and button rows keep the full picker): the
/// key-sequence card's app picker and Lua editor, writing the row's
/// `.run` action. A row with directions or a grab offers neither.
extension GestureListRow {
    /// The row's action container: the app picker while choosing an
    /// app, the picker otherwise.
    @ViewBuilder var actionContainer: some View {
        if choosingApp {
            AppPickerButton(
                placeholder: L("shortcuts.choose_app", "Choose app…"),
                selection: nil,
                onPick: pickApp,
                escapeLabel: L("shortcuts.other_ellipsis", "Other…"),
                onEscape: {
                    if let app = AppBundlePanel.pick() { pickApp(app) }
                },
                opensOnAppear: true,
                onClose: { choosingApp = false }
            )
            .fixedSize()
        } else {
            actionMenu
                .popover(item: $editingLua) { _ in
                    luaPopover.settingsPopoverChrome()
                }
        }
    }

    /// The row's Lua, read and written through its `.run` action.
    var luaText: Binding<String> {
        Binding(
            get: {
                if case .run(let run) = action { return run.lua }
                return ""
            },
            set: { lua in
                var run = LuaAction(lua: lua, kind: .custom)
                if case .run(let old) = action { run.meta = old.meta }
                bind(.run(run))
            }
        )
    }

    /// The row's description, beside its Lua.
    var luaDesc: Binding<String> {
        Binding(
            get: {
                if case .run(let run) = action { return run.meta.desc }
                return ""
            },
            set: { desc in
                guard case .run(var run) = action else { return }
                run.meta.desc = desc
                bind(.run(run))
            }
        )
    }

    /// Lua…: the row turns into a Lua action, an existing one kept,
    /// and its editor opens.
    func startLua() {
        var isLua = false
        if case .run(let run) = action { isLua = run.kind == .custom }
        if !isLua { bind(.run(LuaAction(lua: "", kind: .custom))) }
        editingLua = LuaEditRequest(id: entry.id)
    }

    func pickApp(_ app: KeybindingCatalog.InstalledApp) {
        bind(
            .run(
                LuaAction(
                    lua: KeybindingCatalog.appCommand(app.bundleID),
                    kind: .application,
                    meta: KeyBindingMeta(desc: app.name)
                )
            )
        )
    }

    private var luaPopover: some View {
        LuaBindingEditor(
            title: L("shortcuts.lua.editor_title", "Lua binding"),
            spokenName: L(
                "shortcuts.lua.body_ax",
                "Lua for %1$@",
                GestureListWords.input(key.input)
            ),
            placeholder: L(
                "shortcuts.lua_placeholder",
                "Lua, e.g. KiwiDesk.reload_config()"
            ),
            text: luaText,
            changeAction: {
                editingLua = nil
                // The picker opens once this popover has gone.
                DispatchQueue.main.async {
                    picking = SequencePickRequest(id: entry.id)
                }
            },
            dismiss: { editingLua = nil }
        ) {
            TextField(
                L("shortcuts.lua.desc_placeholder", "Description"),
                text: luaDesc
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(
                L(
                    "shortcuts.lua.desc_ax",
                    "Description for %1$@",
                    GestureListWords.input(key.input)
                )
            )
        }
    }
}
