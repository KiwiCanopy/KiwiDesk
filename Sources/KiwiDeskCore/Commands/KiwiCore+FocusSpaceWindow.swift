import Foundation

/// `focus_space_window(direction)` (#3183 ▸ Ruling: directions of a
/// family row): one step of the window list — the active Space's
/// next or previous window in its own order, floats included,
/// wrapping at the ends. The walk family's discrete step, so a
/// split direction can run it; the step is the pan's own
/// (`stepInOrder`), never a copy.
extension KiwiCore {
    func focusSpaceWindow(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = ModeCycleDirection(rawValue: raw)
        else { return .expected(ModeCycleDirection.self) }
        guard let space = activeSpace,
            state.focusAnchor(of: space) != nil
        else { return .fail("no focused window") }
        let step = direction == .next ? 1 : -1
        guard
            stepInOrder(
                space,
                toward: Self.direction(step, horizontal: true),
                by: step
            )
        else { return .fail("the Space has no other window to focus") }
        return .ok()
    }
}
