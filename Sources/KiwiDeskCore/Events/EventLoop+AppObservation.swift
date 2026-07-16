import AppKit
import ApplicationServices

/// Per-app AX observer ownership and rule-driven attachment.
extension EventLoop {
    /// Reconciles app-level observation with the current ignore
    /// rules. An ignored app has no AX observer, no enhanced-UI
    /// flag, and no tracked windows.
    func syncObservation(
        for app: NSRunningApplication
    ) {
        let pid = app.processIdentifier
        let ref = AppRef(app)
        let isIgnored = shouldIgnoreApp(bundleID: ref.bundleID)
        guard
            Self.shouldAttach(
                pid: pid,
                activationPolicy: app.activationPolicy,
                isIgnored: isIgnored
            )
        else {
            detach(pid: pid, restoreEnhancedUI: true)
            return
        }
        attach(app: app, ref: ref)
    }

    /// Attaches to regular and accessory apps from launch. The
    /// observer is installed before the initial window snapshot,
    /// closing the gap in which an accessory app can create its
    /// first window (#177).
    func attach(app: NSRunningApplication) {
        attach(app: app, ref: AppRef(app))
    }

    private func attach(
        app: NSRunningApplication,
        ref: AppRef
    ) {
        let pid = app.processIdentifier
        guard observers[pid] == nil else { return }
        guard
            Self.shouldAttach(
                pid: pid,
                activationPolicy: app.activationPolicy,
                isIgnored: shouldIgnoreApp(
                    bundleID: ref.bundleID
                )
            )
        else { return }
        guard let observer = AXApplicationObserver(pid: pid)
        else { return }

        observer.onNotification = { [weak self] note, element in
            self?.handle(note, element, pid: pid, app: ref)
        }
        observers[pid] = observer

        let windows = AXHelper.windows(pid: pid)
        if app.activationPolicy == .regular
            || windows.contains(where: Self.isStandardWindow)
        {
            enableEnhancedUI(pid: pid)
        }
        for element in windows {
            track(element, pid: pid, app: ref)
        }
    }

    nonisolated static func isStandardWindow(
        _ element: AXUIElement
    ) -> Bool {
        AXHelper.role(of: element) == kAXWindowRole
            && AXHelper.subrole(of: element)
                == kAXStandardWindowSubrole
    }

    func enableEnhancedUI(pid: pid_t) {
        guard enhancedUIBaselines[pid] == nil,
            let baseline = AXHelper.getEnhancedUserInterface(
                pid: pid
            )
        else { return }
        enhancedUIBaselines[pid] = baseline
        guard !baseline else { return }
        // Keep Electron/WebKit AX trees warm (see AGENTS.md).
        AXHelper.setEnhancedUserInterface(pid: pid, enabled: true)
    }

    func detach(
        pid: pid_t,
        restoreEnhancedUI: Bool
    ) {
        observers.removeValue(forKey: pid)?.invalidate()
        if let baseline = enhancedUIBaselines.removeValue(
            forKey: pid
        ), restoreEnhancedUI, !baseline {
            AXHelper.setEnhancedUserInterface(
                pid: pid,
                enabled: false
            )
        }
        for id in Array(elements[pid, default: [:]].keys) {
            detectedFloating[id] = nil
            ignorePending.remove(id)
            trackedFrames[id] = nil
            tabCarriers.remove(id)
            onEvent(.windowDestroyed(id, wasMinimized: false))
        }
        elements[pid] = nil
    }
}
