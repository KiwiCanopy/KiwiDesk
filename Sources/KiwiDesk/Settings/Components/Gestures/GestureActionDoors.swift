import KiwiDeskCore
import SwiftUI

/// A gesture action's App… and Lua… (#3199 ▸ the action picker,
/// #3321): the app picker in the trigger's place while choosing, the
/// trigger otherwise with its Lua editor anchored on it. One home for
/// a one-action row and a direction alike; each writes its own
/// `LuaAction` through `write`.
struct GestureActionDoors<Menu: View>: View {
    @Binding var choosingApp: Bool
    @Binding var editingLua: LuaEditRequest?
    @Binding var picking: SequencePickRequest?
    /// The trigger's id, which the editor's Change Action reopens.
    let id: UUID
    /// The action written now, nil while none runs.
    let current: LuaAction?
    /// What VoiceOver calls the action, for the editor's fields.
    let subject: String
    let write: (LuaAction) -> Void
    @ViewBuilder let menu: Menu

    var body: some View {
        if choosingApp {
            AppPickerButton(
                placeholder: L("shortcuts.choose_app", "Choose app…"),
                selection: nil,
                onPick: { write(Self.app($0)) },
                escapeLabel: L("shortcuts.other_ellipsis", "Other…"),
                onEscape: {
                    if let app = AppBundlePanel.pick() {
                        write(Self.app(app))
                    }
                },
                opensOnAppear: true,
                onClose: { choosingApp = false }
            )
            .fixedSize()
        } else {
            menu.popover(item: $editingLua) { _ in
                luaPopover.settingsPopoverChrome()
            }
        }
    }

    /// The action opening `app`.
    private static func app(
        _ app: KeybindingCatalog.InstalledApp
    ) -> LuaAction {
        LuaAction(
            lua: KeybindingCatalog.appCommand(app.bundleID),
            kind: .application,
            meta: KeyBindingMeta(desc: app.name)
        )
    }

    private var lua: LuaAction? {
        current?.kind == .custom ? current : nil
    }

    private var luaText: Binding<String> {
        Binding(
            get: { lua?.lua ?? "" },
            set: { text in
                var next = LuaAction(lua: text, kind: .custom)
                if let lua { next.meta = lua.meta }
                write(next)
            }
        )
    }

    private var luaDesc: Binding<String> {
        Binding(
            get: { lua?.meta.desc ?? "" },
            set: { desc in
                guard var next = lua else { return }
                next.meta.desc = desc
                write(next)
            }
        )
    }

    private var luaPopover: some View {
        LuaBindingEditor(
            title: L("shortcuts.lua.editor_title", "Lua binding"),
            spokenName: L(
                "shortcuts.lua.body_ax",
                "Lua for %1$@",
                subject
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
                    picking = SequencePickRequest(id: id)
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
                    subject
                )
            )
        }
    }
}
