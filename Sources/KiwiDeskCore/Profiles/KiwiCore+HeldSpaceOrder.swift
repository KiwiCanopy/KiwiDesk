import Foundation

/// The order held Spaces keep (#1664): a batch holds its relative
/// order in number and in the bar, however many of it a declared
/// set forces to renumber. Writes no `heldSpaces` — that stays
/// `KiwiCore+HeldSpaces.swift`'s.
extension KiwiCore {
    /// Names for `ids`, walked in the order given: each keeps its
    /// own name unless `mustMove` says otherwise or that name does
    /// not number above every name handed out before it, and then
    /// takes the next number past `taken`.
    static func orderedHeldNames(
        _ ids: [SpaceID],
        taken: Set<SpaceID>,
        mustMove: (SpaceID) -> Bool
    ) -> [SpaceID] {
        var taken = taken
        var floor = 0
        return ids.map { id in
            var name = id
            let belowFloor = Int(id.raw).map { $0 <= floor } ?? false
            if mustMove(id) || belowFloor {
                name = SpaceID.nextNumber(past: taken)
                taken.insert(name)
            }
            if let number = Int(name.raw) { floor = max(floor, number) }
            return name
        }
    }

    /// Moves `batch` behind every other Space, in the order given,
    /// since the bar lists a display's Spaces in creation order: a
    /// renumbered Space is created last, behind a named one the
    /// walk kept after it.
    func placeHeldBatchLast(_ batch: [SpaceID]) {
        guard batch.count > 1 else { return }
        let members = Set(batch)
        let rest = state.workspaces.allSpaces.map(\.id)
            .filter { !members.contains($0) }
        state.workspaces.reorder(matching: rest + batch)
    }
}
