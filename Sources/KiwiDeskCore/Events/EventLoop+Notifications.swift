import AppKit
import ApplicationServices

/// Translates a raw AX notification into a typed `KiwiEvent`.
/// Split from `EventLoop.swift` for file size (§2); the
/// tracking/lifecycle plumbing it leans on stays there.
extension EventLoop {
    private func windowID(
        of element: AXUIElement,
        pid: pid_t
    ) -> WindowID? {
        if let id = AXHelper.windowID(of: element) {
            return id
        }
        // Destroyed elements no longer answer queries; fall back
        // to comparing against tracked elements.
        return elements[pid, default: [:]]
            .first { CFEqual($1, element) }?.key
    }

    func handle(
        _ note: String,
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef
    ) {
        // A callback can already be queued when a reload ignores an
        // app or its policy becomes prohibited. It must not recreate
        // state after the observer has been detached.
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
        switch note {
        case kAXWindowCreatedNotification:
            if Self.isStandardWindow(element) {
                warmAccessibilityTree(pid: pid)
            }
            // A native-tab window's create may really be a tab switch
            // (the old tab vanishes as this one appears). Route it
            // through reconcile so it can coalesce into a re-key
            // instead of a spurious new tile; a genuinely new tabbed
            // window still tracks there when nothing vanished. Also
            // route when the app already has a carrier: at the 1→2
            // boundary the promoted single tab has no group of its own
            // yet (#308).
            if AXHelper.hasNativeTabs(element)
                || appHasTabCarrier(pid: pid)
            {
                reconcile(pid: pid, app: app)
            } else {
                track(element, pid: pid, app: app)
            }
        case kAXUIElementDestroyedNotification,
            kAXWindowMiniaturizedNotification:
            if let id = windowID(of: element, pid: pid),
                elements[pid]?[id] != nil
            {
                // A destroyed native-tab carrier (or any window of an
                // app that has one) may be a switch or active-tab
                // close; leave it tracked and let the reconcile below
                // coalesce a re-key or emit the real destroy. A
                // minimize is never a tab close (#308).
                if note == kAXUIElementDestroyedNotification,
                    tabCarriers.contains(id)
                        || appHasTabCarrier(pid: pid)
                {
                    // Deferred to reconcile.
                } else {
                    elements[pid]?[id] = nil
                    detectedFloating[id] = nil
                    trackedFrames[id] = nil
                    tabCarriers.remove(id)
                    onEvent(
                        .windowDestroyed(
                            id,
                            wasMinimized: note
                                == kAXWindowMiniaturizedNotification
                        )
                    )
                }
            }
            // Destroyed elements often cannot be mapped back
            // (and some apps skip the notification entirely),
            // so always diff against the live window list.
            reconcile(pid: pid, app: app)
        case kAXWindowDeminiaturizedNotification:
            track(element, pid: pid, app: app)
        case kAXFocusedWindowChangedNotification:
            // Closing a window nearly always moves focus;
            // reconciling here catches missed destroy events.
            reconcile(pid: pid, app: app)
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            // Focus events carry only managed windows: the
            // reconcile above just settled tracking, so an
            // absent id is an ignored panel (issue #21) —
            // reporting it would emit a focus_change with an
            // empty app and retile focus-driven layouts. Surface
            // the panel gaining focus so KiwiCore can distrust
            // the app's stale focus report on dismiss (#244).
            guard elements[pid]?[id] != nil else {
                if FloatDetection.isBuiltInIgnoredPanel(
                    bundleID: app.bundleID,
                    id: id
                ) {
                    onIgnoredPanelFocus(pid)
                }
                return
            }
            onEvent(.windowFocused(id))
        case kAXWindowMovedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            let frame = AXHelper.frame(of: element)
            if elements[pid]?[id] != nil { trackedFrames[id] = frame }
            onEvent(.windowMoved(id, frame))
        case kAXWindowResizedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            let frame = AXHelper.frame(of: element)
            if elements[pid]?[id] != nil { trackedFrames[id] = frame }
            onEvent(.windowResized(id, frame))
        case kAXTitleChangedNotification:
            guard let id = AXHelper.windowID(of: element) else {
                return
            }
            onEvent(
                .windowTitleChanged(
                    id,
                    AXHelper.title(of: element)
                )
            )
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
        default:
            break
        }
    }
}
