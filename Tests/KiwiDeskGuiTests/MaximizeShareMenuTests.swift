import Testing

@testable import KiwiDesk

/// A Maximize share pop-up offers exactly ¼ ⅓ ½ ⅔ ¾ (#3062, owner
/// 2026-11-08); a stored share outside them shows as one extra
/// checked item and goes once a fraction replaces it.
@Suite("Maximize share pop-up items (#3062)")
@MainActor
struct MaximizeShareMenuTests {
    @Test("A preset share adds no item and checks its fraction")
    func presetAddsNothing() {
        for share in FractionChips.shares {
            #expect(MaximizeShapeRow.offMenuShare(share.value) == nil)
            #expect(MaximizeShapeRow.selection(share.value) == share.value)
        }
        // Typed to the wire's precision, a third is still ⅓.
        #expect(MaximizeShapeRow.offMenuShare(0.3333) == nil)
        #expect(MaximizeShapeRow.selection(0.3333) == 1.0 / 3)
    }

    @Test("A share off the menu is its own checked item")
    func offMenuIsKept() {
        #expect(MaximizeShapeRow.offMenuShare(0.4) == 0.4)
        #expect(MaximizeShapeRow.selection(0.4) == 0.4)
    }
}
