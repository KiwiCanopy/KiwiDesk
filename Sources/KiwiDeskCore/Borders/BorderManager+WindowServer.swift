import AppKit

/// The ring's half of the WindowServer stream (#285): it hears
/// its rings through the one `WindowServerWatch` (#2275), which
/// owns the subscription and fans each event out in its consumer
/// order — the sticky mark ahead of the ring, KiwiVision's plate
/// after it.
extension BorderManager {
    /// Whether geometry tracking uses WindowServer stream for `id`.
    func usesWindowServerTracking(_ id: WindowID) -> Bool {
        overlays[id] != nil && watch.hears(id, as: .ring)
    }

    /// Whether WindowServer tracking is up for the last request.
    var skyLightActive: Bool { watch.isActive }

    /// The ring's hooks, connected once at construction. Unhide
    /// re-asserts order through `restack` even when the bounds
    /// read failed, and restoration stays with that one order.
    func connectRing() {
        watch.connect(
            .ring,
            WindowServerWatch.Hooks(
                frame: { [weak self] id, frame, unhiding in
                    self?.reconciled(
                        id,
                        frame: frame,
                        restoreVisibility: !unhiding
                    )
                },
                restack: { [weak self] id in
                    self?.overlays[id]?.order(relativeTo: id.raw)
                },
                hide: { [weak self] id in self?.overlays[id]?.hide() }
            )
        )
    }

    /// Reconciles a WindowServer frame the watch read, which
    /// stands down while our own animation drives the window (#594).
    func reconciled(
        _ id: WindowID,
        frame: CGRect,
        restoreVisibility: Bool = true
    ) {
        apply(
            id,
            windowFrame: frame,
            restoreVisibility: restoreVisibility
        )
        noteArrivalReport(id, frame: frame)
    }

    /// The ring's request: rings worn, plus dormant ones kept in
    /// the request so a Space switch leaves it unchanged (#1925).
    func requestRingTracking(_ ringed: Set<WindowID>) {
        watch.request(ringed, for: .ring, keeping: Set(dormant.keys))
    }
}
