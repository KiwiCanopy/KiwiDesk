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
            warmAccessibilityTree(pid: pid)
        }
        let displayBounds = FloatDetection.activeDisplayBounds()
        for element in windows {
            track(
                element,
                pid: pid,
                app: ref,
                displayBounds: displayBounds
            )
        }
    }

    nonisolated static func isStandardWindow(
        _ element: AXUIElement
    ) -> Bool {
        AXHelper.role(of: element) == kAXWindowRole
            && AXHelper.subrole(of: element)
                == kAXStandardWindowSubrole
    }

    /// Makes an app's AX tree materialize so its windows show up in
    /// `kAXWindowsAttribute`, by whichever mechanism the app honors:
    /// `AXEnhancedUserInterface` for Electron/WebKit, or
    /// `AXManualAccessibility` for Chromium-family browsers (which
    /// never answer the EUI read). Idempotent; called at attach and
    /// re-tried on later reconciles for cold apps.
    func warmAccessibilityTree(pid: pid_t) {
        guard enhancedUIBaselines[pid] == nil else { return }
        guard
            let baseline = AXHelper.getEnhancedUserInterface(
                pid: pid
            )
        else {
            // The app does not answer the EUI read. Chromium-family
            // browsers (Chrome, Brave, Edge, Arc, …) behave this way
            // and gate their AX tree behind AXManualAccessibility, so
            // the EUI warm-up below can never reach them and their
            // windows never appear in kAXWindowsAttribute. The *set* is
            // what materializes the tree; the ordinary reconcile
            // window re-scan then finds the windows — so set it once
            // (the attribute sticks) rather than re-writing on every
            // reconcile, since the EUI read that would record a
            // baseline stays nil for a Chromium app forever (#360).
            guard manualAXApplied.insert(pid).inserted else { return }
            AXHelper.setManualAccessibility(pid: pid, enabled: true)
            return
        }
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
        // AXManualAccessibility is left set on the app (an eager AX
        // tree is what a managed app wants); only forget the pid so a
        // re-attach re-applies the warm-up (#360).
        manualAXApplied.remove(pid)
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
