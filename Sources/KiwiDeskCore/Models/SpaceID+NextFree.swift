import Foundation

extension SpaceID {
    /// The smallest positive number none of `ids` is called, so a
    /// minted Space is always reachable by a digit binding. Which
    /// ids are taken is `KiwiCore.mintedSpaceNumber`'s for a live
    /// mint (#1175, #1790); the Settings add row asks it of its
    /// draft (#1531).
    public static func smallestFreeNumber(
        among ids: some Sequence<SpaceID>
    ) -> SpaceID {
        let taken = Set(ids.compactMap { Int($0.raw) })
        var number = 1
        while taken.contains(number) { number += 1 }
        return SpaceID(number)
    }

    /// The first number past the highest one `ids` holds — a held
    /// Space whose name is taken here takes it (#1507), so live
    /// `1–5` holding a screen's `3, 4, 5` numbers them `6, 7, 8`
    /// and a digit binding reaches them in order.
    public static func nextNumber(
        past ids: some Sequence<SpaceID>
    ) -> SpaceID {
        let highest = ids.compactMap { Int($0.raw) }.max() ?? 0
        return SpaceID(highest + 1)
    }
}
