import AppKit

/// `show_layout_picker` (#762): the Layout menu's rows as a native
/// menu at the pointer, acting on the Space the pointer's screen
/// shows — on a desk of several screens the pointer is the one
/// unambiguous "this screen". A menu brings arrows, type-select,
/// Return, Escape and VoiceOver for free.
extension KiwiCore {
    func showLayoutPicker() -> CommandResponse {
        let menus = shelves.contextMenus
        let point = menus.pointer()
        guard let space = spaceUnderPointer(point) else {
            return .fail("no Space under the pointer")
        }
        menus.popUp(BarMenu.make(layoutPickerRows(space)), point)
        return .ok()
    }

    /// The Space shown on the screen holding `point` (Cocoa).
    func spaceUnderPointer(_ point: NSPoint) -> SpaceID? {
        let screen = ScreenList.all.first {
            NSMouseInRect(point, $0.frame, false)
        }
        guard let number = screen?.screenNumber else {
            return state.workspaces.activeSpace
        }
        return state.workspaces.activeSpace(on: DisplayID(number))
            ?? state.workspaces.activeSpace
    }

    /// A header naming the Space, then one row per layout from the
    /// one `LayoutModeRows`, the live one checked.
    func layoutPickerRows(_ id: SpaceID) -> [BarMenuRow] {
        guard let space = state.workspaces[id] else { return [] }
        let saved = savedModes(for: [id])[id]
        let rows = LayoutModeRows.entries(
            live: space.mode,
            drifted: LayoutModeRows.drifted(live: space.mode, saved: saved),
            words: LayoutModeRows.coreWords
        ).map { entry in
            BarMenuRow.action(
                entry.title,
                checked: entry.checked,
                symbol: entry.symbol,
                subtitle: entry.subtitle
            ) { [weak self] in
                _ = self?.execute(
                    "set_mode",
                    args: [.string(id.raw), .string(entry.mode.rawValue)]
                )
            }
        }
        return [.header(L("layout_picker.header", "Space %1$@", id.raw))]
            + rows
    }
}
