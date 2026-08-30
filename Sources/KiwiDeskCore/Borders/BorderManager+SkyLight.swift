import AppKit

/// WindowServer event integration and geometry tracking for
/// `BorderManager` (#285). The manager is the WS-events broker
/// for two consumers — the ring and the sticky mark's tees —
/// because `SkyLightWindowEvents` has a single weak sink. Two is
/// a deliberate deferral; a THIRD is the trigger to extract a
/// standalone `WindowServerWatch` service (#414).
extension BorderManager {
    /// Configures WindowServer tracking from the environment
    /// (`KIWIDESK_NO_WS_TRACKING`, #596). Named after
    /// `StrandDetector.configureFromEnvironment` but NOT its twin:
    /// where `KIWIDESK_STRAND_LOG` only turns on logging, this
    /// kills a production fast path for the whole run.
    func configureFromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo
            .environment
    ) {
        let value = environment["KIWIDESK_NO_WS_TRACKING"]
        windowServerTrackingDisabled = !(value?.isEmpty ?? true)
    }

    /// Whether geometry tracking uses WindowServer stream for `id`.
    func usesWindowServerTracking(_ id: WindowID) -> Bool {
        overlays[id] != nil && skyLightActive
    }

    /// Whether sticky mark should consume WindowServer stream for `id` (#414).
    func markUsesWindowServerTracking(_ id: WindowID) -> Bool {
        skyLightActive
            && (overlays[id] != nil || stickyTracked.contains(id))
    }

    /// Updates sticky mark window watch set in WindowServer subscription
    /// (#414).
    func setStickyTracked(_ ids: Set<WindowID>) {
        guard ids != stickyTracked else { return }
        stickyTracked = ids
        updateSkyLightSubscription(Set(overlays.keys))
    }

    /// Handles a WindowServer notification. The guard is scoped
    /// to windows we watch EITHER way (ring or sticky-tracked); a
    /// window watched neither way is a stale additive delivery
    /// (`watch(_:)`'s undocumented semantics) and is dropped.
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
            // Unhide must re-assert order even when the bounds
            // read fails; restoration stays with that one explicit
            // order so a successful reconcile cannot issue it
            // twice.
            _ = reconcile(id, restoreVisibility: false)
            onWindowReordered(id)
            overlays[id]?.order(relativeTo: id.raw)
        case .hide:
            overlays[id]?.hide()
        }
    }

    /// Reconciles authoritative WindowServer bounds unless window is animating
    /// (#594).
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
        let wanted = borderWanted.union(stickyTracked)
        let wasActive = skyLightActive
        if windowServerTrackingDisabled {
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

    /// The one line telling a QA run which path it is on — names
    /// the lever explicitly when it forced the fallback, or an
    /// unexplained "unavailable" on a healthy Mac reads as a real
    /// WindowServer failure.
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
