import Foundation

/// Z-order raise generation (#418/#425) in a lock, not on the
/// main actor: the drain reads it between raises to abandon a
/// superseded sequence (#684). Minted ONLY by `stampZOrderRaise`
/// on MainActor — `@unchecked Sendable` makes an off-actor
/// `bump()` compile, and it would silently invalidate every
/// in-flight sequence's identity.
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
