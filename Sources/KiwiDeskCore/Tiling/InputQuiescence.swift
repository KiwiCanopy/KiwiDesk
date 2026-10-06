import CoreGraphics
import Foundation

/// Whether the hand is at rest, for ambient window motion (#804 ▸
/// Ruling): buttons up and the mouse quiet for `quietGap`; past
/// `patience` of holding, buttons up alone. Keyboard activity never
/// counts. Main actor; every read is a seam `makeTestCore` pins.
@MainActor
final class InputQuiescence {
    /// A moving mouse is aiming; this long still, it is not.
    static let quietGap: TimeInterval = 0.3
    /// Past this much holding, motion waits only for buttons up.
    static let patience: TimeInterval = 3
    /// How often a hold re-asks while it waits.
    static let poll: TimeInterval = 0.05

    /// Whether any mouse button is down — `MouseTracker`'s one
    /// read, wired at bootstrap; unwired, no button is down.
    var buttonsDown: @MainActor () -> Bool = { false }
    /// Seconds since the mouse last moved, a drag included, from
    /// WindowServer's own record — no event monitor, no permission.
    var sinceMouseMoved: @MainActor () -> TimeInterval = {
        let moves: [CGEventType] = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .otherMouseDragged,
        ]
        return moves.map {
            CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: $0
            )
        }.min() ?? .infinity
    }

    /// Whether ambient motion may run now, given how long it has
    /// been held (nil: not held yet).
    func admits(heldFor: TimeInterval?) -> Bool {
        guard !buttonsDown() else { return false }
        if sinceMouseMoved() >= Self.quietGap { return true }
        return (heldFor ?? 0) >= Self.patience
    }
}
