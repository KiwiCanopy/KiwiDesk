import AppKit

/// The WindowServer integration for `BorderManager` (#285 Tier 2):
/// the notification sink, the per-window watch subscription, and the
/// tracking predicates. Split out of `BorderManager.swift` to keep
/// each file under the size ceiling; the stored state it touches
/// (`overlays`, `eventSource`, `skyLightActive`, `stickyTracked`, …)
/// is internal on the main type for exactly this reason.
///
/// `BorderManager` is now the WindowServer-events broker for two
/// consumers — the ring (its overlays) and the sticky mark (via the
/// `onFrameReconciled` / `onWindowReordered` tees) — because
/// `SkyLightWindowEvents` has a single weak sink. Two consumers is a
/// deliberate deferral; a THIRD would be the trigger to extract a
/// standalone `WindowServerWatch` service with peer subscribers (#414).
extension BorderManager {
    /// Reads the `KIWIDESK_NO_WS_TRACKING` QA lever (#596). Any
    /// non-empty value keeps `skyLightActive` false for the whole
    /// run, so the ring and mark exercise the AX-fallback path
    /// the settle-tail symptoms live on. Call once at wiring; the
    /// environment parameter is the test seam (the strand
    /// detector's `configureFromEnvironment`, mirrored).
    func configureFromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo
            .environment
    ) {
        let value = environment["KIWIDESK_NO_WS_TRACKING"]
        windowServerTrackingDisabled = !(value?.isEmpty ?? true)
    }

    /// Geometry tracking is independent of rendering. If a raw SLS
    /// window falls back to AppKit, that panel can still follow real
    /// bounds from a healthy WindowServer event stream.
    func usesWindowServerTracking(_ id: WindowID) -> Bool {
        overlays[id] != nil && skyLightActive
    }

    /// Whether the sticky mark should trust the WindowServer stream
    /// for this window (and suppress the laggy AX echo), mirroring
    /// `usesWindowServerTracking` for the ring. True for any window
    /// we actually watch — bordered OR sticky-tracked — once the
    /// stream is live.
    func markUsesWindowServerTracking(_ id: WindowID) -> Bool {
        skyLightActive
            && (overlays[id] != nil || stickyTracked.contains(id))
    }

    /// The sticky mark's WS tracking set (#414 QA): sticky windows
    /// need the reorder tee and frame stream even with no ring, so
    /// they are folded into the watch subscription here. Driven by
    /// `updateStickyMarks`; a no-op when unchanged.
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
    /// Scoped guard, not the ring's old overlay-only one: a
    /// sticky-tracked window may wear a mark but no ring, so it must
    /// pass too — it needs the same WS frame stream (`reconcile` →
    /// `onFrameReconciled`) and z-order tee (`onWindowReordered`).
    /// A window we watch neither way is a stale additive delivery
    /// (`watch(_:)`'s undocumented semantics) and is dropped, so no
    /// stray bounds read or tee fan-out fires for it.
    func handleSkyLightEvent(
        _ kind: SkyLightWindowEvents.Kind,
        window id: WindowID
    ) {
        guard overlays[id] != nil || stickyTracked.contains(id)
        else { return }
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

    /// Re-reads the authoritative WindowServer bounds (the drag
    /// stream, unhide). Floating windows do not retile, so their
    /// final ring must be reconciled on button-up. Stands down
    /// while OUR OWN animation drives the window (#594): the WS
    /// bounds trail the commanded per-tick frame on slow-AX
    /// apps, so mid-animation every event would rewind the ring
    /// behind the motion. The first WS event after settle
    /// reconciles any residual drift.
    @discardableResult
    func reconcile(
        _ id: WindowID,
        restoreVisibility: Bool = true
    ) -> Bool {
        guard !isAnimating(id) else { return false }
        guard let frame = readWindowBounds(id) else {
            return false
        }
        apply(
            id,
            windowFrame: frame,
            restoreVisibility: restoreVisibility
        )
        onFrameReconciled(id, frame)
        return true
    }

    func updateSkyLightSubscription(
        _ borderWanted: Set<WindowID>
    ) {
        guard privateRuntimeStarted else {
            skyLightActive = false
            return
        }
        // Sticky marks ride the same stream as rings (#414 QA), so
        // their windows join the watch set even without a ring.
        let wanted = borderWanted.union(stickyTracked)
        let wasActive = skyLightActive
        if windowServerTrackingDisabled {
            // Never attach or watch under the lever: a live
            // subscription would keep feeding `reconcile`, which
            // heals exactly the drift the fallback path is meant
            // to expose.
            skyLightActive = false
        } else {
            if !triedEventSource, !wanted.isEmpty {
                triedEventSource = true
                eventSource = SkyLightWindowEvents.shared
                eventSource?.attach(self)
            }
            skyLightActive = eventSource?.watch(wanted) == true
        }
        if reportedTrackingActive != skyLightActive {
            reportedTrackingActive = skyLightActive
            onLog(trackingStatusMessage)
        }
        if wasActive, !skyLightActive {
            for overlay in overlays.values {
                overlay.useAppKitFallback()
            }
        }
    }

    /// The one line that tells a QA run which path it is on.
    /// Names the lever explicitly when it is what forced the
    /// fallback: an unexplained "unavailable" on a healthy Mac
    /// would read as a real WindowServer failure.
    private var trackingStatusMessage: String {
        if skyLightActive {
            return "WindowServer border tracking active"
        }
        if windowServerTrackingDisabled {
            return "WindowServer border tracking disabled by "
                + "KIWIDESK_NO_WS_TRACKING; using AX fallback"
        }
        return "WindowServer border tracking unavailable; "
            + "using AX fallback"
    }
}
