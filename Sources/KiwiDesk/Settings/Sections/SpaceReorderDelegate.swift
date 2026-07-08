import KiwiDeskCore
import SwiftUI

/// Live reordering for the Spaces list: attached to every row,
/// it moves the dragged space in the array the moment the drag
/// *enters* a row — the other rows animate out of the way, so
/// the opening gap always shows exactly where the drop will
/// land. (The old drop-on-row handler reordered only on release
/// and inserted strictly before the target, which made a
/// one-step downward drag a silent no-op.)
///
/// Identity rides the shared `dragged` binding, not the drag
/// payload — a same-view drag never needs to decode anything.
/// A drag that didn't start in this list leaves `dragged` nil
/// and is rejected by `validateDrop`.
struct SpaceReorderDelegate: DropDelegate {
    let item: SpaceID
    @Binding var spaces: [SpaceID]
    @Binding var dragged: SpaceID?

    func validateDrop(info: DropInfo) -> Bool {
        dragged != nil
    }

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != item,
            let from = spaces.firstIndex(of: dragged),
            let to = spaces.firstIndex(of: item)
        else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            spaces.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        return true
    }
}
