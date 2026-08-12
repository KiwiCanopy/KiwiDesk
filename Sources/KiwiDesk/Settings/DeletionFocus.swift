/// Where the keyboard lands after a deletion (#816).
///
/// The rule is one sentence — **the next row, else the previous,
/// else nowhere, read from the list BEFORE the mutation** — and
/// it was written six times in six comments across five lists
/// before this existed. Each copy was correct; none of them
/// owned the rule, so a seventh list would have restated it, and
/// the parity guard cannot tell a neighbour read before the
/// delete from one read after (both spell
/// `returningRow = neighbour`).
///
/// Reading it AFTER the mutation is the failure worth naming:
/// the list then reports whichever row slid into the gap, which
/// is right by accident everywhere except at the end of a list,
/// where the deleted row's index no longer exists and focus
/// falls off it.
///
/// Deliberately a free function over the DISPLAY order rather
/// than a protocol: what varies between the lists is which order
/// is on screen (sorted by display name in App Rules, profile
/// order in Profiles, the drag order in Spaces), and that is the
/// argument, not the stepping.
enum DeletionFocus {
    /// The neighbour of `item` in `list`: the next one, else the
    /// previous, else nil when it was the only row.
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
