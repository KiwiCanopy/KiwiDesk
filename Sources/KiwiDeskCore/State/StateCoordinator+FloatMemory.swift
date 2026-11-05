import CoreGraphics
import Foundation

/// The per-window float records that live as long as the window.
extension StateCoordinator {
    /// One remembered float frame and the process that owns it.
    struct FloatFrame: Sendable, Equatable {
        let pid: pid_t
        let frame: CGRect
    }

    /// A float's judged aspect lock (#2973): `ratio` is width / height
    /// while locked, nil for a window judged not to hold one.
    struct FloatAspect: Sendable, Equatable {
        let pid: pid_t
        var ratio: CGFloat?
    }

    /// The judgement in flight: a press's ask, then a written probe.
    /// Means nothing once `.floatAspect` is no longer scheduled.
    enum FloatAspectFlight: Sendable, Equatable {
        case asking(WindowID, axis: String, grows: Bool)
        case probing(WindowID)
    }

    /// Carries both records across a native-tab re-key. A judgement in
    /// flight is not carried: it ends unjudged at its next read.
    mutating func rekeyFloatMemory(_ old: WindowID, to new: WindowID) {
        if let frame = floatFrames.removeValue(forKey: old) {
            floatFrames[new] = frame
        }
        if let aspect = floatAspects.removeValue(forKey: old) {
            floatAspects[new] = aspect
        }
    }
}
