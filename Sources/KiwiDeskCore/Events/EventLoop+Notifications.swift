import AppKit
import ApplicationServices

/// Translates a raw AX notification into a typed `KiwiEvent`.
/// Split from `EventLoop.swift` for file size (§2); the
/// tracking/lifecycle plumbing it leans on stays there.
extension EventLoop {
    /// The window an AX notification is about — from the
    /// TRACKED map first, and only then by asking the app
    /// (#1084).
    ///
    /// `AXHelper.windowID(of:)` is `_AXUIElementGetWindow`, a
    /// synchronous MIG round-trip into the other process. It
    /// costs 1–20 ms when that app is idle and unboundedly more
    /// when it is busy, and it runs on the main thread — which
    /// is the thread the `CADisplayLink` callback is delivered
    /// on. So paying it per notification starved our own frame
    /// clock: device capture 2026-08-28 measured 42 stalls in
    /// ten seconds of held resize, up to 607 ms (6–30 frames
    /// never delivered), with ~37% of main-thread samples
    /// blocked in that call. Every applied frame emits a
    /// move/resize notification, so a resize funds its own
    /// starvation.
    ///
    /// The map answers the same question for a window we
    /// already track — which, during a resize, is all of them —
    /// with an in-process `CFEqual` scan over that app's
    /// windows and no IPC at all.
    ///
    /// **It needs no invalidation, and that is why it is the
    /// map rather than a cache of its own.** `elements` is
    /// dropped per pid on app termination, per window on a
    /// vanish, and re-keyed (old key removed first) on a native
    /// tab switch — so it holds at most one id per element and
    /// never a stale one. A destroyed or unknown element simply
    /// fails to match and falls through to the ask, which is
    /// also what makes this safe against the #308 recycled-id
    /// hazard: a recycled id arrives on a NEW element, which
    /// cannot `CFEqual` the old one.
    ///
    /// The ask stays as the fallback, and stays SECOND: it is
    /// the only answer for a window not yet adopted, and the
    /// only thing that can tell us a brand-new window's id.
    private func windowID(
        of element: AXUIElement,
        pid: pid_t
    ) -> WindowID? {
        if let id = elements[pid, default: [:]]
            .first(where: { CFEqual($1, element) })?.key
        {
            return id
        }
        return resolveWindowID(element)
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
                    releaseWindowRegistration(id, pid: pid)
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
                classifyUntrackedFocus(
                    id: id,
                    pid: pid,
                    bundleID: app.bundleID,
                    isAccessory: classifiesAsOverlay(pid: pid),
                    channel: "focus"
                )
                return
            }
            onEvent(.windowFocused(id))
        case kAXWindowMovedNotification:
            guard let id = windowID(of: element, pid: pid) else {
                return
            }
            requestFrameRead(
                .moved,
                id: id,
                element: element,
                pid: pid
            )
        case kAXWindowResizedNotification:
            guard let id = windowID(of: element, pid: pid) else {
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
            // Observer PRESENCE alone, not the full
            // `ownsObservation` funnel: the policy re-read
            // exists to catch an app whose policy changed with
            // its observer still installed, and `handle`
            // already ran it at receipt — a policy flip inside
            // the read's flight still ends in a detach, which
            // clears the observer and closes this guard. The
            // funnel's extra term would buy that narrowing at
            // an `NSRunningApplication` lookup per delivered
            // frame, on the main actor, at storm rate.
            guard self.observers[pid] != nil else { return }
            if self.elements[pid]?[id] != nil {
                self.trackedFrames[id] = frame
            }
            switch kind {
            case .moved:
                self.onEvent(.windowMoved(id, frame))
            case .resized:
                self.onEvent(.windowResized(id, frame))
            case .settleProbe:
                // Never requested through this wire — the
                // #677 probe (`KiwiCore.runSizeBoundProbe`)
                // passes its own completion and emits no
                // event.
                break
            }
        }
    }

    /// Releases one window's registration — the ONE copy of the
    /// destroy cleanup, called by the destroy arm above and by a
    /// path that KNOWS the window left rather than observing it
    /// leave (#1023's eager departure: a follow onto a hidden
    /// Desktop). A state-only removal is not enough there: the
    /// element left registered makes the window "already known"
    /// to every later reconcile and to the heal's census diff,
    /// so nothing ever re-adopts it — the exact half-state this
    /// exists to prevent. One copy on purpose (parity-tests.md's
    /// drift warning): a second hand-list of these maps would
    /// let one caller stop clearing what the other clears.
    /// Emits no event: each caller owns its own fold or emit,
    /// so the registry and the fold cannot double-report.
    func releaseWindowRegistration(_ id: WindowID, pid: pid_t) {
        elements[pid]?[id] = nil
        detectedFloating[id] = nil
        detectedFullscreen[id] = nil
        trackedFrames[id] = nil
        tabCarriers.remove(id)
    }
}
