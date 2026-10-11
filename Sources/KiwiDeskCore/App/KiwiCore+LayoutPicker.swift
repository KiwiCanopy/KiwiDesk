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

    /// The Space shown on the screen holding `point` (Cocoa), else
    /// the active one.
    func spaceUnderPointer(_ point: NSPoint) -> SpaceID? {
        let screens = ScreenList.all.compactMap { screen in
            screen.kiwiDisplayID.map { (frame: screen.frame, id: $0) }
        }
        return Self.display(at: point, among: screens)
            .flatMap { state.workspaces.activeSpace(on: $0) }
            ?? state.workspaces.activeSpace
    }

    /// Which of `screens` holds `point`, through the one lookup
    /// the pointer's other readers take.
    nonisolated static func display(
        at point: CGPoint,
        among screens: [(frame: CGRect, id: DisplayID)]
    ) -> DisplayID? {
        GeometryUtils.screenIndex(
            holding: point,
            in: screens.map(\.frame)
        ).map { screens[$0].id }
    }

    /// A header naming the Space, then the Layout menu's rows.
    func layoutPickerRows(_ id: SpaceID) -> [BarMenuRow] {
        let rows = layoutModeMenuRows(for: id)
        guard !rows.isEmpty else { return [] }
        return [.header(L("layout_picker.header", "Space %1$@", id.raw))]
            + rows
    }
}
