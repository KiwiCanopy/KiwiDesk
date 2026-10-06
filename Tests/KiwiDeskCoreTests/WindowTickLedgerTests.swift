import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **`forget` clears every per-window store the ledger holds**
/// (#1104). The stores are read by reflection, so one added to
/// `WindowTickLedger` reds `everyStoreIsFilled` until this fixture
/// fills it — and then `forget` has to clear it.
@Suite("Window tick ledger (#1104)")
struct WindowTickLedgerTests {
    private let id = WindowID(7)
    private let other = WindowID(8)

    private func filled() -> WindowTickLedger {
        var ledger = WindowTickLedger()
        for window in [id, other] {
            ledger.heldSize[window] = CGSize(width: 10, height: 10)
            ledger.sizeElapsed[window] = 0.5
            ledger.lastApplied[window] = CGRect(
                x: 0,
                y: 0,
                width: 10,
                height: 10
            )
        }
        return ledger
    }

    /// Each store's entry count, by reflection.
    private func counts(_ ledger: WindowTickLedger) -> [String: Int] {
        Mirror(reflecting: ledger).children.reduce(into: [:]) {
            out,
            child in
            if let label = child.label,
                let store = child.value as? any Collection
            {
                out[label] = store.count
            }
        }
    }

    @Test("the fixture fills every store")
    func everyStoreIsFilled() {
        let ledger = filled()
        let seen = counts(ledger)
        #expect(
            seen.count == Mirror(reflecting: ledger).children.count
        )
        #expect(seen.values.allSatisfy { $0 == 2 }, "\(seen)")
    }

    @Test("forget clears one window from every store")
    func forgetClearsEveryStore() {
        var ledger = filled()
        ledger.forget(id)
        let seen = counts(ledger)
        #expect(!seen.isEmpty)
        #expect(seen.values.allSatisfy { $0 == 1 }, "\(seen)")
        #expect(ledger.heldSize[id] == nil)
        #expect(ledger.heldSize[other] != nil)
    }
}
