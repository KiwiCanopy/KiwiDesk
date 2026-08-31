import Foundation

/// Thread-safe generation counter for z-order raise sequences (#418, #684).
/// Only minted by `stampZOrderRaise` on MainActor.
final class ZOrderGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0

    var value: Int { lock.withLock { current } }

    /// Starts a new sequence, returning its generation.
    func bump() -> Int {
        lock.withLock {
            current += 1
            return current
        }
    }
}
