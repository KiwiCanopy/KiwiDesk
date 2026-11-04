import CoreGraphics
import Foundation

/// The per-window float records that live as long as the window.
extension StateCoordinator {
    /// One remembered float frame and the process that owns it.
    struct FloatFrame: Sendable, Equatable {
        let pid: pid_t
        let frame: CGRect
    }

    /// What a float's answers showed (#2973): `ratio` is width / height
    /// while locked; `freeAxes` took a one-axis ask; `refusedAsks` are
    /// the asks it refused, at `refusedSize`, which it leaves if it ever
    /// complies. A refused shrink says nothing of a grow.
    struct FloatAspect: Sendable, Equatable {
        let pid: pid_t
        var ratio: CGFloat?
        var freeAxes: Set<String> = []
        var refusedAsks: Set<String> = []
        var refusedSize: CGSize? = nil

        static func ask(axis: String, delta: Double) -> String {
            axis + (delta > 0 ? "+" : "-")
        }

        func refuses(axis: String, delta: Double) -> Bool {
            refusedAsks.contains(Self.ask(axis: axis, delta: delta))
        }

        /// Nothing left to learn from this press.
        func isJudged(axis: String, delta: Double) -> Bool {
            ratio != nil || freeAxes.contains(axis)
                || refuses(axis: axis, delta: delta)
        }

        /// A press needs no read of the window: free here, with no
        /// refusal whose evidence it could outlive.
        func skipsRead(axis: String) -> Bool {
            ratio == nil && refusedSize == nil && freeAxes.contains(axis)
        }
    }

    /// The judgement in flight: a press's ask, then a written probe.
    /// Means nothing once `.floatAspect` is no longer scheduled.
    enum FloatAspectFlight: Sendable, Equatable {
        case asking(WindowID, axis: String)
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
