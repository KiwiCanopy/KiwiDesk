import CoreGraphics
import Foundation

/// The tick loop's per-window bookkeeping: the size a window holds
/// mid-animation, how long its size stepper has run, and the last
/// frame applied (#1104, `WindowTickLedgerTests`).
struct WindowTickLedger {
    var heldSize: [WindowID: CGSize] = [:]
    var sizeElapsed: [WindowID: TimeInterval] = [:]
    var lastApplied: [WindowID: CGRect] = [:]

    /// Clears `id` from every store.
    mutating func forget(_ id: WindowID) {
        heldSize[id] = nil
        sizeElapsed[id] = nil
        lastApplied[id] = nil
    }
}
