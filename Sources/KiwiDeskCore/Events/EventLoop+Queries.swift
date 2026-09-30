import ApplicationServices

/// Read-only lookups into the event loop's tracking tables — used
/// by the tiler (geometry apply), the float verbs, the
/// focused-command preflight (#292), and native-Space raise
/// safety. None mutate; they keep `EventLoop.swift` focused on
/// tracking and dispatch.
extension EventLoop {
    /// Last float-detection verdict of a tracked window — what a
    /// Tile returns a window to, and why it refuses (#1810). Nil
    /// for untracked windows.
    public func detectionVerdict(for id: WindowID) -> FloatVerdict? {
        detectedFloating[id]
    }

    /// Whether the event loop still owns an AX observer for `pid`
    /// — i.e. the app is managed, not ignored/unmanaged/quit. The
    /// focused-command preflight (#292) requires this so a shortcut
    /// can't act while an unobserved app holds the foreground.
    public func observes(pid: pid_t) -> Bool {
        observers[pid] != nil
    }

    /// AX element of a tracked window, if still known. Used to
    /// apply geometry (animations, wake restore) to windows.
    public func element(for id: WindowID) -> AXUIElement? {
        for perApp in elements.values {
            if let element = perApp[id] {
                return element
            }
        }
        return nil
    }
}
