import ApplicationServices

/// The visible-panel distrust's one door (#21, #448), which
/// states the title-bar button of an untracked window as every
/// reader of the ignore predicate does (#2344).
extension EventLoop {
    /// Whether `pid` shows a visible ignored panel: the gate's
    /// admitted ids left out, an untracked window's button asked.
    /// A caller of the scan takes this door, never
    /// `FloatDetection.hasVisibleIgnoredPanel` beside it.
    func showsIgnoredPanel(
        pid: pid_t,
        bundleID: String?,
        isAccessory: Bool
    ) -> Bool {
        FloatDetection.hasVisibleIgnoredPanel(
            pid: pid,
            bundleID: bundleID,
            isAccessory: isAccessory,
            tracked: admittedWindows(of: pid),
            titlebarButton: untrackedTitlebarButton(of: pid)
        )
    }

    /// The title-bar button of `pid`'s untracked window, read as
    /// the gate reads it. The app's window list is read once,
    /// only when a candidate asks, and resolved only as far as
    /// the asked id; a window it does not list has no button.
    /// The read runs on the main actor, as the callers' own
    /// focused-window read does.
    private func untrackedTitlebarButton(
        of pid: pid_t
    ) -> (WindowID) -> Bool {
        var list: [AXUIElement]?
        var next = 0
        var resolved: [WindowID: AXUIElement] = [:]
        return { [weak self] id in
            guard let self else { return false }
            if let element = resolved[id] {
                return Self.readsTitlebarButton(element, id: id)
            }
            let windows = list ?? self.axWindows(pid)
            list = windows
            while next < windows.count {
                let element = windows[next]
                next += 1
                let window: WindowID?
                switch self.trackedMatch(of: element, pid: pid) {
                case .one(let tracked): window = tracked
                case .none, .ambiguous:
                    window = self.resolveWindowID(element)
                }
                guard let window else { continue }
                resolved[window] = resolved[window] ?? element
                if window == id {
                    return Self.readsTitlebarButton(element, id: id)
                }
            }
            return false
        }
    }
}
