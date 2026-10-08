import Foundation

/// The Space order's in-place sort, split from `WorkspaceManager`
/// at the §2.1 ceiling.
extension WorkspaceManager {
    /// Sorts `ids` by number within the slots they already hold in
    /// the order, every other Space staying where it is; a name
    /// that is not a number follows the numbers. True when it moved
    /// one.
    @discardableResult
    public mutating func sortInPlace(_ ids: Set<SpaceID>) -> Bool {
        let sorted = order.filter(ids.contains).sorted {
            switch (Int($0.raw), Int($1.raw)) {
            case (let a?, let b?): return a < b
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return $0.raw < $1.raw
            }
        }
        var next = sorted.makeIterator()
        let reordered = order.map { ids.contains($0) ? next.next()! : $0 }
        guard reordered != order else { return false }
        order = reordered
        return true
    }
}
