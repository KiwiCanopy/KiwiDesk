import Foundation

/// The Space order's in-place sort, split from `WorkspaceManager`
/// at the §2.1 ceiling.
extension WorkspaceManager {
    /// Sorts `ids` by number within the slots they already hold
    /// on their OWN screen, every other Space staying where it is:
    /// a screen's row is `spaces(on:)`, so a swap across screens
    /// could carry one past a declared or held Space on either.
    /// True when it moved one.
    @discardableResult
    public mutating func sortInPlace(_ ids: Set<SpaceID>) -> Bool {
        guard !ids.isEmpty else { return false }
        let slots = order.indices.filter { ids.contains(order[$0]) }
        let byScreen = Dictionary(grouping: slots) {
            display(of: order[$0])
        }
        var reordered = order
        for group in byScreen.values {
            let sorted = SpaceID.numericLexicalSorted(group.map { order[$0] })
            for (slot, id) in zip(group, sorted) { reordered[slot] = id }
        }
        guard reordered != order else { return false }
        order = reordered
        return true
    }
}
