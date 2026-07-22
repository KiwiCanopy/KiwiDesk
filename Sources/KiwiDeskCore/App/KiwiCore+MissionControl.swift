import Foundation

/// Mission Control / Exposé handling. KiwiDesk's overlays would
/// otherwise float over the overview: the focus ring is a sticky
/// WindowServer window and the bars and sticky chips are
/// `.stationary` panels, so none of them vanish with the windows
/// they annotate. While the overview is up every overlay is hidden
/// and its refresh gated; on exit the normal `update*()` paths
/// rebuild them.
extension KiwiCore {
    /// Starts watching Mission Control. A no-op (leaving overlays
    /// visible in the overview, as before) when the Dock AX element
    /// can't be reached.
    func startMissionControlObserver() {
        missionControl = MissionControlObserver { [weak self] active in
            self?.setMissionControlActive(active)
        }
    }

    /// Hides every overlay on entry and rebuilds them on exit. The
    /// `missionControlActive` flag gates the overlay `update*()`
    /// refreshes so a stray event mid-overview cannot re-show one;
    /// the ring additionally rides the always-on WindowServer event
    /// stream, so `borders.setSuspended` gates that path too.
    func setMissionControlActive(_ active: Bool) {
        guard active != missionControlActive else { return }
        missionControlActive = active
        borders.setSuspended(active)
        if active {
            appBars.sync([])
            spaceBars.sync([])
            stickyIndicators.sync([])
        } else {
            updateBorders()
            updateAppBar()
            updateSpaceBar()
            updateStickyIndicators()
        }
    }
}
