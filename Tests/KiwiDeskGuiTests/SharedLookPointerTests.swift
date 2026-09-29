import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The shared-look pointer's two sentences each place their link
/// at a positional slot (#1752), so a locale can move it; the call
/// site sits in `CrossReferenceRowSlotTests`' register.
@Suite("Shared look pointer (#1752)")
@MainActor
struct SharedLookPointerTests {
    @Test("both arms place the link")
    func bothArmsPlaceTheLink() {
        LocalizationManager.shared.select("en")
        let slot = CrossReferenceRow.linkSlot
        #expect(SharedLookPointer.sharedProse.contains(slot))
        #expect(SharedLookPointer.ownProse.contains(slot))
    }
}
