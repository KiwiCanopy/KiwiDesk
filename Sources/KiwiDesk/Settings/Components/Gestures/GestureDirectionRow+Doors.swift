import KiwiDeskCore
import SwiftUI

/// A direction's action container (#3321): the catalogue picker
/// with App… and Lua…, as a one-action row offers them, each
/// writing this direction's arm alone.
extension GestureDirectionRow {
    var actionContainer: some View {
        GestureActionDoors(
            choosingApp: $choosingApp,
            editingLua: $editingLua,
            picking: $picking,
            id: id,
            current: arm,
            subject: spokenLabel,
            write: pick
        ) {
            actionMenu
        }
    }

    /// While the row binds a family the trigger reads in secondary
    /// ink (#3199 ▸ Ruling); the picker it opens keeps its own.
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

    /// Lua…: the editor opens, and the arm turns into Lua only once
    /// some is typed, so an empty editor leaves the arm, and a family
    /// its pan, as they were.
    func startLua() {
        editingLua = LuaEditRequest(id: id)
    }
}
