import AppKit
import KiwiDeskCore

/// What the pointer lifts in KiwiHub (#2365): the item under it,
/// grey, while the green selection stays where the keys or a
/// click put it.
enum JumpHover: Equatable {
    case row(Int)
    case item(ViewPickList.Pick)
    /// A tile of the Windows side's app strip (#3135).
    case tile(Int)

    /// Whether `target` draws the lift: the item under the pointer,
    /// never the selected one, whose accent wins (#1173), and never
    /// one a click would leave alone — the lift promises the click
    /// (owner ruling 2026-10-17).
    static func lifts(
        _ target: JumpHover,
        hover: JumpHover?,
        selected: Bool,
        clickable: Bool
    ) -> Bool {
        hover == target && !selected && clickable
    }

    /// The row a held ⇧ or ⌥ speaks for (#2808, #2885): the lifted
    /// row, which its click would act on, else the selection, which
    /// ↩ acts on — one row at a time, its route or its refusal.
    static func actedRow(hover: JumpHover?, selection: Int?) -> Int? {
        guard case .row(let index) = hover,
            lifts(
                .row(index),
                hover: hover,
                selected: index == selection,
                clickable: true
            )
        else { return selection }
        return index
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

    func hoverTile(_ index: Int, pointer: CGPoint) {
        guard scope == .windows else { return }
        noteHover(.tile(index), pointer: pointer)
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
