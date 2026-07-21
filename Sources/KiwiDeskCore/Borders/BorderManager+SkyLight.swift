import AppKit

/// The WindowServer integration for `BorderManager` (#285 Tier 2):
/// the notification sink, the per-window watch subscription, and the
/// tracking predicates. Split out of `BorderManager.swift` to keep
/// each file under the size ceiling; the stored state it touches
/// (`overlays`, `eventSource`, `skyLightActive`, `stickyTracked`, …)
/// is internal on the main type for exactly this reason.
extension BorderManager {
    /// Geometry tracking is independent of rendering. If a raw SLS
    /// window falls back to AppKit, that panel can still follow real
    /// bounds from a healthy WindowServer event stream.
    func usesWindowServerTracking(_ id: WindowID) -> Bool {
        overlays[id] != nil && skyLightActive
    }

    /// Whether the sticky chip should trust the WindowServer stream
    /// for this window (and suppress the laggy AX echo), mirroring
    /// `usesWindowServerTracking` for the ring. True for any window
    /// we actually watch — bordered OR sticky-tracked — once the
    /// stream is live.
    func chipUsesWindowServerTracking(_ id: WindowID) -> Bool {
        skyLightActive
            && (overlays[id] != nil || stickyTracked.contains(id))
    }

    /// The sticky chip's WS tracking set (#414 QA): sticky windows
    /// need the reorder tee and frame stream even with no ring, so
    /// they are folded into the watch subscription here. Driven by
    /// `updateStickyIndicators`; a no-op when unchanged.
    func setStickyTracked(_ ids: Set<WindowID>) {
        guard ids != stickyTracked else { return }
        stickyTracked = ids
        updateSkyLightSubscription(Set(overlays.keys))
    }

    /// Receives the WindowServer notifications registered by
    /// `SkyLightWindowEvents`. Bounds are read from SkyLight's cache,
    /// never AX, then fed through the same geometry path as animation
    /// and cursor following.
    ///
    /// No border-overlay guard: a sticky-tracked window may wear a
    /// chip but no ring, and it needs the same WS frame stream
    /// (`reconcile` → `onFrameReconciled`) and z-order tee
    /// (`onWindowReordered`). The ring's own actions stay guarded
    /// per case (`overlays[id]?`).
    func handleSkyLightEvent(
        _ kind: SkyLightWindowEvents.Kind,
        window id: WindowID
    ) {
        switch kind.action {
        case .follow:
            _ = reconcile(id)
        case .reorder:
            onWindowReordered(id)
            overlays[id]?.order(relativeTo: id.raw)
        case .followAndReorder:
            // Unhide must re-assert order even when the bounds read
            // fails. Leave restoration to that one explicit order so
            // a successful reconcile cannot issue it twice.
            _ = reconcile(id, restoreVisibility: false)
            onWindowReordered(id)
            overlays[id]?.order(relativeTo: id.raw)
        case .hide:
            overlays[id]?.hide()
        }
    }

    func updateSkyLightSubscription(
        _ borderWanted: Set<WindowID>
    ) {
        guard privateRuntimeStarted else {
            skyLightActive = false
            return
        }
        // Sticky chips ride the same stream as rings (#414 QA), so
        // their windows join the watch set even without a ring.
        let wanted = borderWanted.union(stickyTracked)
        if !triedEventSource, !wanted.isEmpty {
            triedEventSource = true
            eventSource = SkyLightWindowEvents.shared
            eventSource?.attach(self)
        }
        let wasActive = skyLightActive
        skyLightActive = eventSource?.watch(wanted) == true
        if reportedTrackingActive != skyLightActive {
            reportedTrackingActive = skyLightActive
            let mode =
                skyLightActive
                ? "WindowServer border tracking active"
                : "WindowServer border tracking unavailable; "
                    + "using AX fallback"
            onLog(mode)
        }
        if wasActive, !skyLightActive {
            for overlay in overlays.values {
                overlay.useAppKitFallback()
            }
        }
    }
}
