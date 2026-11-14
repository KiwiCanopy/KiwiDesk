import KiwiDeskCore
import SwiftUI

/// A direction's action container (#3321): the catalogue picker
/// with App… and Lua…, as a one-action row offers them, each
/// writing this direction's arm alone.
extension GestureDirectionRow {
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

    /// While the row binds a family the trigger reads in secondary
    /// ink; the picker it opens keeps its own (#3321).
    private var actionMenu: some View {
        SequenceActionMenu(
            face: face,
            catalog: catalog,
            spokenLabel: spokenLabel,
            pins: [],
            onPick: { command in
                guard
                    case .run(let arm) = GestureListEdits.action(
                        picking: command
                    )
                else { return }
                pick(arm)
            },
            onApp: { choosingApp = true },
            onLua: startLua,
            onEditLua: { editingLua = LuaEditRequest(id: id) },
            request: $picking
        )
        .foregroundStyle(
            inherited ? SettingsTheme.ink2 : SettingsTheme.ink
        )
    }

    /// The direction's own arm, nil while it runs nothing.
    var arm: LuaAction? {
        GestureListEdits.arms(of: action, on: key.input)?[direction]
    }

    /// Lua…: the arm turns into a Lua action, an existing one kept,
    /// and its editor opens.
    func startLua() {
        if arm?.kind != .custom {
            pick(LuaAction(lua: "", kind: .custom))
        }
        editingLua = LuaEditRequest(id: id)
    }

    func pickApp(_ app: KeybindingCatalog.InstalledApp) {
        pick(
            LuaAction(
                lua: KeybindingCatalog.appCommand(app.bundleID),
                kind: .application,
                meta: KeyBindingMeta(desc: app.name)
            )
        )
    }

    /// The arm's Lua, read and written through the arm.
    private var luaText: Binding<String> {
        Binding(
            get: { arm?.kind == .custom ? arm?.lua ?? "" : "" },
            set: { lua in
                var next = LuaAction(lua: lua, kind: .custom)
                if let arm, arm.kind == .custom { next.meta = arm.meta }
                pick(next)
            }
        )
    }

    private var luaDesc: Binding<String> {
        Binding(
            get: { arm?.kind == .custom ? arm?.meta.desc ?? "" : "" },
            set: { desc in
                guard var next = arm, next.kind == .custom else { return }
                next.meta.desc = desc
                pick(next)
            }
        )
    }

    private var luaPopover: some View {
        LuaBindingEditor(
            title: L("shortcuts.lua.editor_title", "Lua binding"),
            spokenName: L(
                "shortcuts.lua.body_ax",
                "Lua for %1$@",
                spokenLabel
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
                    spokenLabel
                )
            )
        }
    }
}
