import Foundation

/// Every KiwiShelf element's visibility at once (#761, #2978): the
/// Space Bar's, each hosting layout's App Bar's and the pocket's, the
/// one set its readers and writers share (`BarVisibilitySetTests`).
extension TilingSettings {
    /// The visibility every element shares — the Space Bar's, each
    /// hosting layout's App Bar and the pocket — or nil while they
    /// differ: what Settings' Show master selects (#761, #2978).
    public var uniformBarVisibility: ShelfVisibility? {
        let all =
            [spaceBarStyle.visibility] + appBarHosts.map(\.visibility)
            + [kiwishelf.pocketVisibility]
        return Set(all).count == 1 ? all.first : nil
    }

    /// Sets every element's own visibility at once — each still
    /// stored per bar, per layout and for the pocket, nothing linked
    /// (#761, #2978).
    public mutating func setEveryBarVisibility(_ visibility: ShelfVisibility) {
        spaceBarStyle.visibility = visibility
        kiwishelf.pocketVisibility = visibility
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

    /// `other`'s visibility on every element, nothing else of it — a
    /// tour step's Revert (#2515).
    public mutating func takeBarVisibility(from other: TilingSettings) {
        spaceBarStyle.visibility = other.spaceBarStyle.visibility
        kiwishelf.pocketVisibility = other.kiwishelf.pocketVisibility
        for mode in LayoutMode.allCases {
            guard let path = Self.appBarPath(for: mode) else { continue }
            self[keyPath: path].visibility =
                other[keyPath: path].visibility
        }
    }
}
