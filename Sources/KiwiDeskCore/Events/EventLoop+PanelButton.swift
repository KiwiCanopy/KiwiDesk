import ApplicationServices

/// The visible-panel distrust's one door (#21, #448), which
/// states the title-bar button of an untracked window as every
/// reader of the ignore predicate does (#2344), and its subrole
/// (#2239).
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
        let window = untrackedWindow(of: pid)
        return FloatDetection.hasVisibleIgnoredPanel(
            pid: pid,
            bundleID: bundleID,
            isAccessory: isAccessory,
            tracked: admittedWindows(of: pid),
            subrole: { window($0).map(AXHelper.subrole(of:)) ?? "" },
            titlebarButton: { id in
                window(id).map { Self.readsTitlebarButton($0, id: id) }
                    == true
            }
        )
    }

    /// The element of `pid`'s untracked window, for reading it as
    /// the gate reads it. The app's window list is read once,
    /// only when a candidate asks, and resolved only as far as
    /// the asked id; a window it does not list has none. The
    /// read runs on the main actor, as the callers' own
    /// focused-window read does. Internal for its suite alone; a
    /// caller takes `showsIgnoredPanel`.
    func untrackedWindow(
        of pid: pid_t
    ) -> (WindowID) -> AXUIElement? {
        var list: [AXUIElement]?
        var next = 0
        var resolved: [WindowID: AXUIElement] = [:]
        return { [weak self] id in
            guard let self else { return nil }
            if let element = resolved[id] { return element }
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
                if window == id { return element }
            }
            return nil
        }
    }
}
