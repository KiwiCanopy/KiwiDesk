import Foundation

/// Every bar's visibility at once (#761): the Space Bar's and each
/// hosting layout's App Bar's, the one set its readers and writers
/// share (`BarVisibilitySetTests`).
extension TilingSettings {
    /// The visibility every bar shares — the Space Bar's and each
    /// hosting layout's App Bar — or nil while they differ: what
    /// Settings' Show master selects (#761).
    public var uniformBarVisibility: ShelfVisibility? {
        let all = [spaceBarStyle.visibility] + appBarHosts.map(\.visibility)
        return Set(all).count == 1 ? all.first : nil
    }

    /// Sets every bar's own visibility at once — each still stored
    /// per bar and per layout, nothing linked (#761).
    public mutating func setEveryBarVisibility(_ visibility: ShelfVisibility) {
        spaceBarStyle.visibility = visibility
        for mode in LayoutMode.allCases {
            setAppBarVisibility(visibility, in: mode)
        }
    }

    /// `mode`'s App Bar visibility, where the mode hosts one —
    /// through the one `appBarPath(for:)`.
    public mutating func setAppBarVisibility(
        _ visibility: ShelfVisibility,
        in mode: LayoutMode
    ) {
        guard let path = Self.appBarPath(for: mode) else { return }
        self[keyPath: path].visibility = visibility
    }

    /// `other`'s visibility on every bar, nothing else of it — a
    /// tour step's Revert (#2515).
    public mutating func takeBarVisibility(from other: TilingSettings) {
        spaceBarStyle.visibility = other.spaceBarStyle.visibility
        for mode in LayoutMode.allCases {
            guard let path = Self.appBarPath(for: mode) else { continue }
            self[keyPath: path].visibility =
                other[keyPath: path].visibility
        }
    }
}
