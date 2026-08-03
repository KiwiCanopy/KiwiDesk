import AppKit
import ApplicationServices

/// Window tracking: classify one AX window element and fold it
/// into the tracked set. Split from `EventLoop.swift` for file
/// size (§2); the reconcile funnel that drives it in bulk lives
/// in `EventLoop+Reconcile.swift`.
extension EventLoop {
    func track(
        _ element: AXUIElement,
        pid: pid_t,
        app: AppRef,
        displayBounds: [CGRect]? = nil
    ) {
        let role = AXHelper.role(of: element)
        guard role == kAXWindowRole,
            !AXHelper.isMinimized(element),
            var window = AXHelper.snapshot(
                element: element,
                pid: pid,
                app: app
            )
        else { return }
        guard elements[pid]?[window.id] == nil else { return }
        let subrole = AXHelper.subrole(of: element)
        // One WindowServer round trip feeds every
        // classification below (layer, alpha, bounds).
        let server = FloatDetection.serverSnapshot(
            of: window.id
        )
        let layer = server.layer
        let displays =
            layer == nil || layer == 0
            ? []
            : displayBounds
                ?? FloatDetection.activeDisplayBounds()
        guard
            !FloatDetection.isUnbackedAuxiliary(
                role: role,
                subrole: subrole,
                layer: layer
            )
        else {
            markTransientDrop(pid: pid, id: window.id)
            return
        }
        // #309: an invisible raised-layer helper (alpha-0 or
        // fully off-screen lifecycle keepalive) never enters
        // state — tracked, it would earn a Space slot and an
        // App Bar item and read as an open app. A genuine
        // overlay caught mid fade-in is re-tracked by a later
        // reconcile pass — the one-shot re-track below is the
        // pass that is *guaranteed* to come (#675).
        guard
            !FloatDetection.isInvisibleHelper(
                layer: layer,
                alpha: server.alpha,
                bounds: server.bounds,
                displays: displays
            )
        else {
            markTransientDrop(pid: pid, id: window.id)
            return
        }
        // Some panels must never be managed at all — merely
        // floating them still pins them to a space (issue #21;
        // #448 extends this to accessory apps' raised-layer
        // command bars).
        let isAccessory = classifiesAsOverlay(pid: pid)
        guard
            !shouldIgnore(
                element,
                pid: pid,
                app: app,
                layer: layer ?? 0,
                isAccessory: isAccessory
            )
        else {
            return
        }
        window.isFloating =
            shouldForceFloat(pid: pid)
            || FloatDetection.shouldFloat(
                element: element,
                bundleID: app.bundleID,
                layer: layer,
                rules: floatRules
            )
        // A transient overlay floats for a *structural* reason
        // (third-party accessory app, panel subrole, or raised
        // layer), never just because a float rule matched — so a
        // user-floated standard window keeps its ring while a
        // launcher does not (#300). Our own Settings window is
        // exempt (#315, see `classifiesAsOverlay`).
        window.isTransientOverlay =
            isAccessory
            || FloatDetection.shouldFloat(
                role: role,
                subrole: subrole,
                layer: layer ?? 0
            )
        // Native fullscreen suppresses the focus ring (a ring
        // around a display-filling window shows only at the
        // corners); snapshot it here, refresh on reconcile.
        window.isFullscreen = AXHelper.isFullscreen(element)
        detectedFloating[window.id] = window.isFloating
        detectedFullscreen[window.id] = window.isFullscreen
        elements[pid, default: [:]][window.id] = element
        observers[pid]?.observe(window: element)
        // Remember every window's frame, and which windows carry a
        // native tab group, so a later switch (this window vanishing
        // as a sibling appears at the same frame) coalesces into a
        // re-key instead of a destroy + create (#308).
        trackedFrames[window.id] = window.frame
        if AXHelper.hasNativeTabs(element) {
            tabCarriers.insert(window.id)
        }
        onEvent(.windowCreated(window))
    }

    /// Queues one delayed re-track for a window a transient
    /// filter dropped (#675). Mid-launch (a Dock-stack zoom, a
    /// fade-in) a window can read unbacked or alpha-0 once, and
    /// both filters return with no retry — the only healing pass
    /// was whatever reconcile happened to come, which for a
    /// fresh launch may be none. One retry per window id, so a
    /// permanent invisible helper (#309) re-drops once on the
    /// retry and then stays quiet; the ledger clears with its
    /// app (`detach`).
    func markTransientDrop(pid: pid_t, id: WindowID) {
        guard
            transientRetried[pid, default: []]
                .insert(id).inserted
        else { return }
        pendingRetrack.insert(pid)
        onTransientDrop()
    }

    /// Hands the pids owed a re-track to the scheduled task and
    /// clears the queue (#675).
    func drainPendingRetrack() -> Set<pid_t> {
        let pids = pendingRetrack
        pendingRetrack = []
        return pids
    }

    /// Re-runs float detection on an already-tracked window.
    /// A window scanned mid-launch or mid-animation can report
    /// a wrong subrole once (Ghostty's quick terminal during
    /// the startup scan) and would otherwise stay misclassified
    /// until it closes. Only a changed detection verdict emits,
    /// so manual make_floating overrides survive reconciles.
    // Internal (not private): also called by `handle` in
    // EventLoop+Notifications.swift.
    func recheckFloat(
        _ element: AXUIElement,
        id: WindowID,
        pid: pid_t,
        app: AppRef
    ) {
        recheckFullscreen(element, id: id)
        let floating =
            shouldForceFloat(pid: pid)
            || FloatDetection.shouldFloat(
                element: element,
                bundleID: app.bundleID,
                rules: floatRules
            )
        guard detectedFloating[id] != floating else { return }
        detectedFloating[id] = floating
        onEvent(.windowFloatChanged(id, isFloating: floating))
    }

    /// Re-reads native-fullscreen state on reconcile so a
    /// green-button transition (no destroy/create pair) flips
    /// the snapshot flag and the focus ring follows. Change-only,
    /// like the float recheck above.
    private func recheckFullscreen(
        _ element: AXUIElement,
        id: WindowID
    ) {
        let fullscreen = AXHelper.isFullscreen(element)
        guard detectedFullscreen[id] != fullscreen else { return }
        detectedFullscreen[id] = fullscreen
        onEvent(
            .windowFullscreenChanged(
                id,
                isFullscreen: fullscreen
            )
        )
    }
}
