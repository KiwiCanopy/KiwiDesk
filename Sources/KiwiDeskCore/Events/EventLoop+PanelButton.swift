import ApplicationServices

/// The title-bar button the visible-panel distrust asks of an
/// untracked window (#2344), beside the gate's admitted ids.
extension EventLoop {
    /// The title-bar button of `pid`'s untracked window, read as
    /// the gate reads it. The app's window list is read once, and
    /// only when a candidate asks; a window it does not list has
    /// no button.
    func untrackedTitlebarButton(
        of pid: pid_t
    ) -> (WindowID) -> Bool {
        var listed: [WindowID: AXUIElement]?
        return { [weak self] id in
            guard let self else { return false }
            if listed == nil {
                var found: [WindowID: AXUIElement] = [:]
                for element in self.axWindows(pid) {
                    guard
                        let window = self.windowID(
                            of: element,
                            pid: pid,
                            arm: "panel button"
                        )
                    else { continue }
                    found[window] = found[window] ?? element
                }
                listed = found
            }
            guard let element = listed?[id] else { return false }
            return Self.readsTitlebarButton(element, id: id)
        }
    }
}
