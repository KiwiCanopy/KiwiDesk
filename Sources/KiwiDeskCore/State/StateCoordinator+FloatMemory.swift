import CoreGraphics
import Foundation

/// The per-window float records that live as long as the window:
/// a float's frame and aspect, a Tile over a float rule and a
/// maximized float's return frame (#3036).
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

    /// Carries the records across a native-tab re-key. A judgement in
    /// flight is not carried: it ends unjudged at its next read.
    mutating func rekeyFloatMemory(_ old: WindowID, to new: WindowID) {
        if let frame = floatFrames.removeValue(forKey: old) {
            floatFrames[new] = frame
        }
        if let aspect = floatAspects.removeValue(forKey: old) {
            floatAspects[new] = aspect
        }
        if let pid = tiledOverRule.removeValue(forKey: old) {
            tiledOverRule[new] = pid
        }
        if let frame = maximizedFloatReturn.removeValue(forKey: old) {
            maximizedFloatReturn[new] = frame
        }
    }

    /// Ends every record above for an app that exited.
    mutating func forgetFloatMemory(pid: pid_t) {
        floatFrames = floatFrames.filter { $0.value.pid != pid }
        floatAspects = floatAspects.filter { $0.value.pid != pid }
        tiledOverRule = tiledOverRule.filter { $0.value != pid }
        maximizedFloatReturn = maximizedFloatReturn.filter {
            $0.value.pid != pid
        }
    }

    /// Ends the per-window records for a window gone for good: a
    /// close or an away window's retirement.
    mutating func forgetFloatMemory(of id: WindowID) {
        floatFrames[id] = nil
        floatAspects[id] = nil
        tiledOverRule[id] = nil
        maximizedFloatReturn[id] = nil
    }

    /// Whether a Tile keeps `id` tiled over a float rule (#2975):
    /// its record names the window's own process.
    func tilesOverRule(_ id: WindowID) -> Bool {
        guard let pid = tiledOverRule[id] else { return false }
        return windows[id]?.pid == pid
    }

    /// Tiles `id` over its float rule, or ends that and floats it
    /// again: the flag alone, never `userFloated`, so the rule
    /// removed later leaves no float of the user's behind.
    mutating func setTiledOverRule(_ id: WindowID, _ tiled: Bool) {
        guard let window = windows[id] else { return }
        tiledOverRule[id] = tiled ? window.pid : nil
        userFloated.remove(id)
        windows.setFloating(id, !tiled)
    }
}
