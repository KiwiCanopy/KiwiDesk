import Foundation

/// The Spaces a profile declares, and their display order.
extension Profile {
    /// All spaces declared across ordered list, modes, Main, or pins.
    public var declaredSpaces: Set<SpaceID> {
        var all = Set(spaces)
        all.formUnion(spaceModes.keys)
        all.formUnion(mainSpaces)
        for set in monitorSets {
            all.formUnion(set.spaceMonitorMap.keys)
        }
        return all
    }

    /// Authoritative display order with unlisted declared spaces appended.
    public var orderedSpaces: [SpaceID] {
        if spaces.isEmpty {
            return SpaceID.numericLexicalSorted(
                Array(declaredSpaces)
            )
        }
        let stored = Set(spaces)
        let extra = declaredSpaces.subtracting(stored)
        return spaces
            + SpaceID.numericLexicalSorted(Array(extra))
    }
}
