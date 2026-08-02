import AppKit
import ApplicationServices

/// Start/stop lifecycle. Split from `EventLoop.swift` for file
/// size (§2); the attach path it drives lives in
/// `EventLoop+AppObservation.swift`.
extension EventLoop {
    /// Starts observing. Requires Accessibility permission.
    ///
    /// One `CGWindowListCopyWindowInfo` snapshot before the app
    /// loop identifies PIDs with at least one layer-0 window.
    /// Apps without visible windows skip the expensive AX window
    /// query and warmup — the AXObserver is still installed so
    /// future `kAXWindowCreatedNotification`s fire, and the
    /// 1-second startup sweep (`reconcileAll`) re-warms any cold
    /// app whose window appeared in the interim.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        // Bound every AX message before the first per-app call:
        // the scan below is serial and an unresponsive app
        // otherwise costs the ~6 s system default per call
        // (#672).
        applyAXMessagingTimeout(Self.axMessagingTimeoutSeconds)
        registerWorkspaceObservers()
        let signposter = BootSignpost.signposter
        let scan = signposter.beginInterval("startupScan")
        let begin = ContinuousClock.now
        let visible = visiblePIDs()
        let apps = runningApplications()
        for app in apps {
            attach(
                app: app,
                hasVisibleWindows: visible.contains(
                    app.processIdentifier
                )
            )
        }
        signposter.endInterval("startupScan", scan)
        let ms = begin.duration(to: .now).wholeMilliseconds
        onLog(
            "startup scan: \(observers.count) apps attached "
                + "of \(apps.count) running in \(ms)ms"
        )
        publishDisplays()
    }

    /// Stops observing and forgets all tracked windows.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        let center = NSWorkspace.shared.notificationCenter
        for token in workspaceTokens {
            center.removeObserver(token)
        }
        workspaceTokens = []
        if let screenToken {
            NotificationCenter.default
                .removeObserver(screenToken)
        }
        screenToken = nil
        for observer in observers.values {
            observer.invalidate()
        }
        for (pid, baseline) in enhancedUIBaselines
        where !baseline {
            AXHelper.setEnhancedUserInterface(
                pid: pid,
                enabled: false
            )
        }
        observers = [:]
        elements = [:]
        enhancedUIBaselines = [:]
        manualAXApplied = []
        detectedFloating = [:]
        detectedFullscreen = [:]
        ignorePending = []
        trackedFrames = [:]
        tabCarriers = []
    }
}
