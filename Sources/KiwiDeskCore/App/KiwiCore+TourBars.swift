import Foundation

/// The welcome tour's bars step (#2515): when the bars show,
/// written through like the looks step's paint (#1720) and
/// reverted on the visibility leaves alone (#761).
extension KiwiCore {
    /// Sets every bar's visibility live and in the live profile's
    /// file; false, writing nothing, where every bar already
    /// reads `visibility`.
    @discardableResult
    public func setBarVisibility(_ visibility: ShelfVisibility) -> Bool {
        let set: (inout TilingSettings) -> Void = {
            $0.setEveryBarVisibility(visibility)
        }
        var next = tiler.settings
        set(&next)
        guard next != tiler.settings else { return false }
        writeTourEditThrough(live: set, stored: set)
        return true
    }

    /// Returns every bar's visibility to `baseline`, live and in
    /// the file, and nothing else; refused once another profile
    /// is live.
    @discardableResult
    public func restoreBarVisibility(_ baseline: TourBaseline) -> Bool {
        guard describesLiveProfile(baseline) else { return false }
        writeTourEditThrough(
            live: { $0.takeBarVisibility(from: baseline.live) },
            stored: { settings in
                guard let stored = baseline.stored else { return }
                settings.takeBarVisibility(from: stored)
            }
        )
        return true
    }

    /// Holds every hiding bar shown while `held` — the looks
    /// step's, so a look is painted onto bars the user can see —
    /// over the windows, retiling nothing. Session-only; a stop
    /// releases it.
    public func holdBarsRevealed(_ held: Bool) {
        shelves.reveal.heldOpen = held
    }
}
