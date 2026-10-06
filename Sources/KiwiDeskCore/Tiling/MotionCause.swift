import Foundation

/// Whose window motion is being written (#804 ▸ Ruling). The
/// input-quiescence gate lets `user` motion through only while it
/// runs inside the call its press started; a `late` user tail and
/// `ambient` motion wait for the hand to rest.
enum MotionCause: Equatable, Sendable {
    /// A KiwiDesk control started it at `pressedAt`; `late` once it
    /// runs in a tail that call scheduled.
    case user(pressedAt: Date, late: Bool)
    /// No input in hand: an app's event, boot, a display change,
    /// the wake replay, the CLI/IPC socket — and anything unlabelled.
    case ambient

    /// This cause as a tail the current call schedules carries it.
    var asTail: MotionCause {
        switch self {
        case .user(let pressedAt, _):
            return .user(pressedAt: pressedAt, late: true)
        case .ambient:
            return .ambient
        }
    }
}

/// The open motion scope, kept beside the frame writes that will
/// read it. Main actor; nested scopes restore their parent.
@MainActor
final class MotionScope {
    private(set) var current: MotionCause?

    func with<T, E: Error>(
        _ cause: MotionCause,
        _ body: () throws(E) -> T
    ) throws(E) -> T {
        let parent = current
        current = cause
        defer { current = parent }
        return try body()
    }
}
