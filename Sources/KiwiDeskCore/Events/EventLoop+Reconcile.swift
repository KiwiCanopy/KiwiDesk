import AppKit
import ApplicationServices

/// Window reconciliation — the safety net that syncs tracked windows
/// against an app's live AX window list. Split from `EventLoop.swift`
/// for file size (§2); the tracking primitives it leans on and the
/// native-tab coalescing (`reconcileTabsAndSweep`, EventLoop+Tabs)
/// live in their own files.
extension EventLoop {
    /// Syncs tracked windows with the app's live AX window list.
    /// Removes windows that closed or minimized, and picks up windows
    /// we missed (e.g. deminiaturized). Safety net for macOS's
    /// unreliable AX notifications — without it, closed windows keep
    /// occupying layout slots. `coalesceTabs` is false on a bulk
    /// `reconcileAll` (native-Space switch / reload / wake), where
    /// same-app windows across spaces tile to identical frames and
    /// must not merge (#308).
    func reconcile(
        pid: pid_t,
        app: AppRef,
        coalesceTabs: Bool = true
    ) {
        let activationPolicy =
            NSRunningApplication(
                processIdentifier: pid
            )?.activationPolicy ?? .prohibited
        guard
            Self.ownsObservation(
                hasObserver: observers[pid] != nil,
                pid: pid,
                activationPolicy: activationPolicy,
                isIgnored: shouldIgnoreApp(
                    bundleID: app.bundleID
                )
            )
        else {
            detach(pid: pid, restoreEnhancedUI: true)
            return
        }
        // One window-server snapshot for the whole pass; only
        // apps with an ignore rule need layers at all.
        let layers =
            FloatDetection.requiresWindowLayers(
                bundleID: app.bundleID
            ) ? FloatDetection.windowLayers(pid: pid) : [:]
        let liveElements = AXHelper.windows(pid: pid)
        if activationPolicy == .regular
            || liveElements.contains(where: Self.isStandardWindow)
        {
            // A cold app may not answer the baseline EUI read at
            // attach time. Retry on later reconciles until one
            // succeeds, without taking another window snapshot.
            warmAccessibilityTree(pid: pid)
        }
        var live: Set<WindowID> = []
        var minimized: Set<WindowID> = []
        // Untracked live windows: their `track` is DEFERRED to the
        // sweep so a native-tab switch (a window appearing as its
        // sibling vanishes) coalesces into a re-key before either a
        // create or a destroy is emitted (#308).
        var appeared: [(element: AXUIElement, id: WindowID)] = []
        for element in liveElements {
            guard let id = AXHelper.windowID(of: element)
            else { continue }
            // Minimized windows count as gone. Unlike windows
            // missing from the list entirely (other native
            // Space), they are flagged so state forgets their
            // space (see KiwiEvent.windowDestroyed).
            guard !AXHelper.isMinimized(element) else {
                minimized.insert(id)
                continue
            }
            // An ignored panel stays out of `live`: if the
            // startup scan mistracked it (its layer reads
            // wrong mid-launch), the sweep below untracks it.
            // A tracked window gets one reading of grace —
            // layers flicker during fullscreen transitions,
            // and untracking on a glitch leaks a spurious
            // destroy/create pair to subscribers.
            if shouldIgnore(
                element,
                pid: pid,
                app: app,
                layer: layers[id]
            ) {
                // App-wide user rules are stable config, not a
                // flickering window-server signal. Apply them
                // immediately; the one-reading grace below is
                // only for Ghostty's layer-scoped built-in.
                if shouldIgnoreApp(bundleID: app.bundleID) {
                    ignorePending.remove(id)
                    continue
                }
                if elements[pid]?[id] != nil,
                    !ignorePending.contains(id)
                {
                    ignorePending.insert(id)
                    live.insert(id)
                }
                continue
            }
            ignorePending.remove(id)
            live.insert(id)
            if elements[pid]?[id] == nil {
                appeared.append((element: element, id: id))
            } else {
                recheckFloat(
                    element,
                    id: id,
                    pid: pid,
                    app: app
                )
                // Keep every tracked window's frame current so a
                // later switch matches against its real on-screen
                // frame (the vanished side of a tab switch may be a
                // window that had no tab group of its own — #308).
                trackedFrames[id] = AXHelper.frame(of: element)
            }
        }
        // Also suppress coalescing briefly after a native-Space
        // change, covering targeted reconciles that race the bulk
        // `reconcileAll` (#308 review).
        let recentSpaceSwitch =
            Date().timeIntervalSince(lastNativeSpaceChange)
            < Self.spaceSwitchCoalesceGrace
        reconcileTabsAndSweep(
            pid: pid,
            app: app,
            appeared: appeared,
            live: live,
            minimized: minimized,
            coalesceTabs: coalesceTabs && !recentSpaceSwitch
        )
    }
}
