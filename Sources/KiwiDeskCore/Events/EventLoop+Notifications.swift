import AppKit
import ApplicationServices

/// Translates a raw AX notification into a typed `KiwiEvent`.
/// Split from `EventLoop.swift` for file size (§2); the
/// tracking/lifecycle plumbing it leans on stays there, and the
/// window-id resolution every arm shares is
/// `EventLoop+WindowIDResolution`.
extension EventLoop {
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
            if let id = trackedWindowID(
                of: element,
                pid: pid,
                arm: note
            ), elements[pid]?[id] != nil {
                // A destroyed native-tab carrier (or any window of an
                // app that has one) may be a switch or active-tab
                // close; leave it tracked and let the reconcile below
                // coalesce a re-key or emit the real destroy. A
                // minimize is never a tab close (#308). A carried
                // sticky window's element dies as it leaves the
                // visible Space (#1145) — on a gesture, before the
                // handler that carries it (#1215) — and a
                // fullscreen transition orders the window out
                // (#1272): same deferral, and the sweep's
                // expected-absence arms rule it.
                if note == kAXUIElementDestroyedNotification,
                    tabCarriers.contains(id)
                        || appHasTabCarrier(pid: pid)
                        || expectedAbsence(of: id) != nil
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
            handleFocusedWindowChanged(element, pid: pid, app: app)
        case kAXWindowMovedNotification:
            guard let id = windowID(of: element, pid: pid, arm: note)
            else { return }
            requestFrameRead(
                .moved,
                id: id,
                element: element,
                pid: pid
            )
        case kAXWindowResizedNotification:
            guard let id = windowID(of: element, pid: pid, arm: note)
            else { return }
            requestFrameRead(
                .resized,
                id: id,
                element: element,
                pid: pid
            )
        case kAXTitleChangedNotification:
            handleTitleChanged(element, pid: pid, app: app)
        default:
            break
        }
    }

    /// The frame half of a move/resize notification, read off
    /// the main actor (#618): the notification carries no
    /// geometry, and reading it here blocked the run loop on
    /// IPC into an app that is busiest exactly when it storms.
    /// `AXReadCoalescer` owns the queueing and newest-wins
    /// coalescing; this closure is the delivery — the same
    /// tracked-frame refresh and event the arms used to run
    /// inline, one run-loop hop later.
    private func requestFrameRead(
        _ kind: AXReadCoalescer.Kind,
        id: WindowID,
        element: AXUIElement,
        pid: pid_t
    ) {
        axReads.request(
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
            // A dead element reads as `.zero` (#1084 review):
            // `AXHelper.frame` answers that when the copy fails,
            // and a real on-screen window never has it. Asking
            // the app used to filter these out for free — a
            // destroyed element answered no id, so the arm
            // returned before ever reading — and resolving from
            // the tracked map lost that property, because the
            // map still names a window whose entry the destroy
            // sweep has not reached yet. Without this the frame
            // folds into state and the overlays follow it, which
            // on device looked like a window snapping to the
            // corner during Finder tab merges (2026-08-29).
            guard frame != .zero else { return }
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
    /// destroy cleanup, called by the destroy arm above, the
    /// sweep's genuine-close loop, `detach`'s per-window loop,
    /// the rekey's `from` side (#1157 made those one copy — and
    /// clearing `ignorePending` here is part of that fix: a
    /// recycled id must not inherit a stale #21 grace entry),
    /// and by a
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
        ignorePending.remove(id)
        trackedFrames[id] = nil
        tabCarriers.remove(id)
        removalDistrusted[id] = nil
    }
}
