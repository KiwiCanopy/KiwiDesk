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
                    detectedFullscreen[id] = nil
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
                    id: id,
                    isAccessory: classifiesAsOverlay(pid: pid)
                ) {
                    onIgnoredPanelFocus(pid)
                }
                return
            }
            onEvent(.windowFocused(id))
        case kAXWindowMovedNotification:
            guard let id = resolveWindowID(element) else {
                return
            }
            requestFrameRead(
                .moved,
                id: id,
                element: element,
                pid: pid
            )
        case kAXWindowResizedNotification:
            guard let id = resolveWindowID(element) else {
                return
            }
            requestFrameRead(
                .resized,
                id: id,
                element: element,
                pid: pid
            )
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

    /// The frame half of a move/resize notification, read off
    /// the main actor (#618): the notification carries no
    /// geometry, and reading it here blocked the run loop on
    /// IPC into an app that is busiest exactly when it storms.
    /// `FrameReadCoalescer` owns the queueing and newest-wins
    /// coalescing; this closure is the delivery — the same
    /// tracked-frame refresh and event the arms used to run
    /// inline, one run-loop hop later.
    private func requestFrameRead(
        _ kind: FrameReadCoalescer.Kind,
        id: WindowID,
        element: AXUIElement,
        pid: pid_t
    ) {
        frameReads.request(
            kind,
            window: id,
            element: element,
            pid: pid
        ) { [weak self] frame in
            guard let self else { return }
            // Ownership re-check at delivery: `stop()` and a
            // detach clear the observer, and a read completing
            // after either must not fold a stale event into a
            // torn-down core — a delivery the old inline read
            // could not produce (review, 2026-08-18).
            guard self.observers[pid] != nil else { return }
            if self.elements[pid]?[id] != nil {
                self.trackedFrames[id] = frame
            }
            switch kind {
            case .moved:
                self.onEvent(.windowMoved(id, frame))
            case .resized:
                self.onEvent(.windowResized(id, frame))
            }
        }
    }
}
