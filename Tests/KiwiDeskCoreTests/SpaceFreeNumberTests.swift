import Testing

@testable import KiwiDeskCore

/// One "next Space number" rule (#1531): the smallest positive
/// number no Space is called, so a minted Space is always a digit.
@Suite("Smallest free Space number")
struct SpaceFreeNumberTests {
    @Test("a gap is filled before the end is extended")
    func fillsTheGap() {
        #expect(
            SpaceID.smallestFreeNumber(among: [1, 3, 4]) == SpaceID(2)
        )
        #expect(
            SpaceID.smallestFreeNumber(among: [1, 2, 3]) == SpaceID(4)
        )
        #expect(SpaceID.smallestFreeNumber(among: []) == SpaceID(1))
    }

    @Test("named Spaces take no number")
    func namesAreIgnored() {
        let ids: [SpaceID] = ["Work", "3a", 1]
        #expect(SpaceID.smallestFreeNumber(among: ids) == SpaceID(2))
    }
}
