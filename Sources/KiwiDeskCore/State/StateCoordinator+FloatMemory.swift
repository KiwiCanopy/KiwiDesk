import CoreGraphics
import Foundation

/// The per-window float records that live as long as the window.
extension StateCoordinator {
    /// One remembered float frame and the process that owns it.
    struct FloatFrame: Sendable, Equatable {
        let pid: pid_t
        let frame: CGRect
    }

    /// One judged float: `ratio` is width / height while locked, nil
    /// for a window judged free of a lock (#2973).
    struct FloatAspect: Sendable, Equatable {
        let pid: pid_t
        var ratio: CGFloat?
    }

    /// Carries both records across a native-tab re-key.
    mutating func rekeyFloatMemory(_ old: WindowID, to new: WindowID) {
        if let frame = floatFrames.removeValue(forKey: old) {
            floatFrames[new] = frame
        }
        if let aspect = floatAspects.removeValue(forKey: old) {
            floatAspects[new] = aspect
        }
    }
}
