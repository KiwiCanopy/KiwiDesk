import Foundation

/// The welcome tour's bars step (#2515): when the bars show,
/// written THROUGH like the looks step's paint (#1720) — live and
/// into the live profile's file, non-adopting — and reverted on
/// its own leaves, since a look never carries the visibility
/// (#761) and the looks step's Revert never reaches it.
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
        paintShelfThrough(live: set, stored: set)
        return true
    }

    /// Returns every bar's visibility to `baseline`, live and in
    /// the file, and nothing else; refused once another profile
    /// is live.
    @discardableResult
    public func restoreBarVisibility(_ baseline: ShelfPaintBaseline) -> Bool {
        guard describesLiveProfile(baseline) else { return false }
        paintShelfThrough(
            live: { $0 = Self.barVisibility(of: baseline.live, on: $0) },
            stored: { settings in
                guard let stored = baseline.stored else { return }
                settings = Self.barVisibility(of: stored, on: settings)
            }
        )
        return true
    }

    /// `settings` with `source`'s bar visibilities — the Space
    /// Bar's and each hosting layout's App Bar's — and nothing
    /// else of it.
    static func barVisibility(
        of source: TilingSettings,
        on settings: TilingSettings
    ) -> TilingSettings {
        var out = settings
        out.spaceBarStyle.visibility = source.spaceBarStyle.visibility
        for mode in LayoutMode.allCases {
            guard let path = TilingSettings.appBarPath(for: mode)
            else { continue }
            out[keyPath: path].visibility = source[keyPath: path].visibility
        }
        return out
    }

    /// Holds every hiding bar shown while `held` — the looks
    /// step's, so a look is painted onto bars the user can see —
    /// over the windows, retiling nothing. Session-only; a stop
    /// releases it.
    public func holdBarsRevealed(_ held: Bool) {
        shelves.reveal.heldOpen = held
    }
}
