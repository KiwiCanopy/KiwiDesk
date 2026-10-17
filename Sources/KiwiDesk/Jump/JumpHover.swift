import AppKit
import KiwiDeskCore

/// What the pointer lifts in KiwiHub (#2365): the item under it,
/// grey, while the green selection stays where the keys or a
/// click put it.
enum JumpHover: Equatable {
    case row(Int)
    case item(ViewPickList.Pick)

    /// Whether `target` draws the lift: the item under the pointer,
    /// never the selected one, whose accent wins (#1173).
    static func lifts(
        _ target: JumpHover,
        hover: JumpHover?,
        selected: Bool
    ) -> Bool {
        hover == target && !selected
    }
}

extension JumpModel {
    /// The pointer over a row lifts it, on a real move only
    /// (#2229, #2365): a row that slides under a still pointer — the
    /// panel opening there, a re-rank, a scroll — lights nothing.
    func hoverRow(_ index: Int, pointer: CGPoint) {
        guard scope == .windows else { return }
        noteHover(.row(index), pointer: pointer)
    }

    func hoverItem(_ pick: ViewPickList.Pick, pointer: CGPoint) {
        guard scope == .view else { return }
        noteHover(.item(pick), pointer: pointer)
    }

    /// The pointer left `target`.
    func endHover(_ target: JumpHover) {
        if hover == target { clearHover() }
    }
}
