import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The KiwiShelf card's pointer to the looks (#1684) places its
/// link at the slot; `CrossReferenceRowSlotTests` registers it.
@Suite("Look cross-reference")
@MainActor
struct LookReferenceTests {
    @Test("the look reference places its link")
    func placesItsLink() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            KiwiShelfCard.lookReference.contains(
                CrossReferenceRow.linkSlot
            )
        )
    }
}
