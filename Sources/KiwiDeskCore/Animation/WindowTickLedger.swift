import CoreGraphics
import Foundation

/// The tick loop's per-window bookkeeping, forgotten together
/// (#1104): the size a window holds mid-animation, how long its
/// size stepper has run, and the last frame applied. A store added
/// here is cleared by `forget` and by a teardown's fresh ledger,
/// never by a hand list beside the engine (`WindowTickLedgerTests`).
struct WindowTickLedger {
    var heldSize: [WindowID: CGSize] = [:]
    var sizeElapsed: [WindowID: TimeInterval] = [:]
    var lastApplied: [WindowID: CGRect] = [:]

    mutating func forget(_ id: WindowID) {
        heldSize[id] = nil
        sizeElapsed[id] = nil
        lastApplied[id] = nil
    }
}
