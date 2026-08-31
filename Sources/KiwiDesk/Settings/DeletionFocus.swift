/// Focus return target calculation following row deletion (#816).
enum DeletionFocus {
    /// Determines next focus target in list before deletion (next, else
    /// previous).
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
