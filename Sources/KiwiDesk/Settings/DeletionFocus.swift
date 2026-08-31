/// Focus return target calculation following row deletion (#816).
enum DeletionFocus {
    /// Determines next focus target (next, else previous), read
    /// from the list BEFORE the mutation — read after, the
    /// end-of-list case names a row that no longer exists and
    /// focus falls off (#816).
    static func neighbour<Item: Equatable>(
        after item: Item,
        in list: [Item]
    ) -> Item? {
        guard let index = list.firstIndex(of: item) else {
            return nil
        }
        if index + 1 < list.count { return list[index + 1] }
        return index > 0 ? list[index - 1] : nil
    }
}
