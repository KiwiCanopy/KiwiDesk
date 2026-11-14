import KiwiDeskCore
import SwiftUI

/// A one-action gesture row's App… and Lua… (#3199 ▸ the action
/// picker: click, tap and button rows keep the full picker), writing
/// the row's `.run` action. A row with directions or a grab offers
/// neither.
extension GestureListRow {
    /// The row's action container: the app picker while choosing an
    /// app, the picker otherwise.
    var actionContainer: some View {
        GestureActionDoors(
            choosingApp: $choosingApp,
            editingLua: $editingLua,
            picking: $picking,
            id: entry.id,
            current: run,
            subject: GestureListWords.input(key.input),
            write: { bind(.run($0)) }
        ) {
            actionMenu
        }
    }

    /// Lua…: the row turns into a Lua action, an existing one kept,
    /// and its editor opens.
    func startLua() {
        if run?.kind != .custom {
            bind(.run(LuaAction(lua: "", kind: .custom)))
        }
        editingLua = LuaEditRequest(id: entry.id)
    }

    private var run: LuaAction? {
        if case .run(let run) = action { return run }
        return nil
    }
}
