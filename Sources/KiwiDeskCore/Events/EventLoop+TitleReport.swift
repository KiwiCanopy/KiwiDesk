import ApplicationServices

/// The `kAXTitleChanged` branch (#1088): the id from the tracked
/// map, the title read off the main actor, and the #160 float
/// recheck at delivery.
extension EventLoop {
    /// Routes a title notification through the map and the
    /// off-main title read (#1088, input-and-animation.md). A
    /// miss drops: the notification is registered per window at
    /// `track`, so an unmatched element is a released window.
    func handleTitleChanged(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        guard
            let id = trackedWindowID(
                of: element,
                pid: pid,
                arm: kAXTitleChangedNotification
            )
        else { return }
        axReads.requestTitle(
            window: id,
            element: element,
            pid: pid
        ) { [weak self] title in
            self?.deliverTitleReport(
                id,
                title: title,
                element: element,
                pid: pid,
                app: app
            )
        }
    }

    /// The report's delivery, after the read. A failed copy —
    /// `nil`, never the empty string a window can really carry —
    /// is the dead element the ask used to filter for free.
    private func deliverTitleReport(
        _ id: WindowID,
        title: String?,
        element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        guard observers[pid] != nil, elements[pid]?[id] != nil
        else { return }
        guard let title else {
            onLog("title: w\(id.raw) unreadable at delivery, dropped")
            return
        }
        onEvent(.windowTitleChanged(id, title))
        // Titles load lazily (Electron/WebKit, and any app
        // mid-launch): a window tracked before its title
        // arrives misses `App:Title` float rules forever
        // without a recheck (#160). Gated on a titled rule
        // for this app so ordinary title churn (browsers,
        // terminals) never pays the window-server lookup.
        if floatRules.hasTitleRule(bundleID: app.bundleID) {
            recheckFloat(
                element,
                id: id,
                pid: pid,
                app: app
            )
        }
    }
}
