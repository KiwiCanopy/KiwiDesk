import ApplicationServices

/// The `kAXTitleChanged` branch (#1088): the id from the tracked
/// map, the title read off the main actor, and the #160 float
/// recheck at delivery.
extension EventLoop {
    /// Routes a title notification through the map and the
    /// off-main title read.
    ///
    /// A browser or a terminal storms this notification — every
    /// page load, every command — on the thread that delivers
    /// the `CADisplayLink` callback, and both of the arm's old
    /// reads were blocking IPC into that app: the id
    /// (`_AXUIElementGetWindow`) and the title itself.
    ///
    /// **A miss DROPS rather than asks**, unlike the shared
    /// resolver. Title notifications are registered per WINDOW
    /// at `track` (`AXApplicationObserver.observe(window:)`), so
    /// an element the map does not carry is a window already
    /// RELEASED — a hidden app's (#913), a swept one — and no
    /// consumer of `.windowTitleChanged` reads an untracked id:
    /// state, the bars and the float recheck all key on a
    /// tracked one. A hidden browser loading pages used to pay
    /// the round-trip per notification for an event nobody
    /// folded. An ambiguous match still asks, because both its
    /// ids are tracked and one of them owes the bars this title.
    func handleTitleChanged(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        let id: WindowID
        switch trackedMatch(of: element, pid: pid) {
        case .one(let match):
            id = match
        case .none:
            return
        case .ambiguous:
            guard
                let asked = askWindowID(
                    element,
                    pid: pid,
                    arm: kAXTitleChangedNotification,
                    reason: "ambiguous"
                )
            else { return }
            id = asked
        }
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

    /// The report's delivery, one run-loop hop after the
    /// notification. A failed copy — `nil`, never the empty
    /// string a window can really carry — is the dead element
    /// the ask used to filter for free, dropped here instead.
    private func deliverTitleReport(
        _ id: WindowID,
        title: String?,
        element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        guard observers[pid] != nil else { return }
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
        if elements[pid]?[id] != nil,
            floatRules.hasTitleRule(bundleID: app.bundleID)
        {
            recheckFloat(
                element,
                id: id,
                pid: pid,
                app: app
            )
        }
    }
}
