import CoreGraphics
import Foundation

/// The per-window float records that live as long as the window.
extension StateCoordinator {
    /// One remembered float frame and the process that owns it.
    struct FloatFrame: Sendable, Equatable {
        let pid: pid_t
        let frame: CGRect
    }

    /// One judged float (#2973): `ratio` is width / height while
    /// locked; `refusedAxes` are those on which it refused a grow and a
    /// shrink, at `refusedSize`, which it leaves if it ever complies.
    /// All empty is a window free of a lock.
    struct FloatAspect: Sendable, Equatable {
        let pid: pid_t
        var ratio: CGFloat?
        var refusedAxes: Set<String> = []
        var refusedSize: CGSize? = nil

        /// Nothing further to judge: locked, or free on every axis.
        var isSettled: Bool { ratio != nil || refusedSize == nil }
    }

    /// Carries both records across a native-tab re-key.
    mutating func rekeyFloatMemory(_ old: WindowID, to new: WindowID) {
        if let frame = floatFrames.removeValue(forKey: old) {
            floatFrames[new] = frame
        }
        if let aspect = floatAspects.removeValue(forKey: old) {
            floatAspects[new] = aspect
        }
        if floatAspectProbing == old { floatAspectProbing = new }
    }
}
