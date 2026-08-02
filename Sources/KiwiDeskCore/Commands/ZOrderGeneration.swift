import Foundation

/// The z-order raise generation (#418/#425), in a lock rather
/// than on the main actor: the drain reads it between raises from
/// `zOrderQueue` to abandon a sequence a newer one has superseded
/// (#684), and every other reader is main-actor code that would
/// otherwise have to hop threads to answer it. It lives beside
/// the drain rather than in `App/` with the property that holds
/// it because the off-actor read is the only reason it is not
/// still an `Int` — a deliberate placement, not an oversight.
///
/// **One minting site: `stampZOrderRaise`, on the main actor.**
/// The compiler used to enforce that by isolation and no longer
/// can: `@unchecked Sendable` makes a `bump()` from the raise
/// queue compile, and it would silently invalidate every
/// in-flight sequence's identity — the identity #684 spent a
/// round unifying, since one generation now keys the drain's
/// staleness check, the stamp release and the focus handoff.
/// Read it anywhere; mint it in one place.
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
