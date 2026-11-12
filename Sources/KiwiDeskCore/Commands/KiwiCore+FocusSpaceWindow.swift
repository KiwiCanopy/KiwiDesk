import Foundation

/// `focus_space_window(direction)` (#3183 ▸ Ruling: directions of a
/// family row): one step of the walk family — the active Space's
/// next or previous window, along the row on Scrolling and Monocle,
/// in the Space's own order elsewhere. It runs the pan's own step
/// (`stepScrollPan`), so a split direction pre-filled with it does
/// what the family did.
extension KiwiCore {
    func focusSpaceWindow(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = ModeCycleDirection(rawValue: raw)
        else { return .expected(ModeCycleDirection.self) }
        guard let space = activeSpace,
            state.focusAnchor(of: space) != nil
        else { return .fail("no focused window") }
        let step = direction == .next ? 1 : -1
        guard stepScrollPan(space, by: step, swipe: nil) else {
            return .fail("the Space has no other window to focus")
        }
        return .ok()
    }
}
