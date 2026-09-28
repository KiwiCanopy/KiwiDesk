import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The KiwiShelf and Gaps cards' pointers to the looks (#1684,
/// #1739) place their link at the slot;
/// `CrossReferenceRowSlotTests` registers them.
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
        // The Gaps & Borders twin (#1739).
        #expect(
            GapsEditor.lookReference.contains(
                CrossReferenceRow.linkSlot
            )
        )
    }
}
