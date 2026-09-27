import AppKit

/// A collapsed Space item (#1683) and what every Space item
/// announces, split from `SpaceBarItemView` for the file size.
extension SpaceBarItemView {
    /// How a collapsed Space item draws
    /// (`SpaceBarOverlay.Item.collapsed(to:)`).
    enum Collapse: Equatable {
        /// The identifier and its window count, in the count cell.
        case count(windows: Int)
        /// The identifier alone; none draws it in
        /// `emptyItemColor`.
        case identifier(windows: Int)

        /// The windows the Space holds, announced either way.
        var windows: Int {
            switch self {
            case .count(let windows), .identifier(let windows):
                return windows
            }
        }

        /// What the count cell draws: 0 draws none.
        var countCell: Int {
            if case .count(let windows) = self { return windows }
            return 0
        }

        /// The number an item's badge cell draws — a collapsed
        /// count, else the windows hidden past the cap. The one
        /// formula the length (`Item.badgeCount`) and the view's
        /// layout and style read.
        static func badgeCount(_ collapse: Self?, overflow: Int) -> Int {
            collapse?.countCell ?? overflow
        }
    }

    /// This item's badge cell, through the one formula.
    var badgeCount: Int {
        Collapse.badgeCount(collapse, overflow: overflow)
    }

    /// Announced whatever the glyph draws (bars.md): a layer
    /// item names its layer, a Space item its Space and count.
    var axLabel: String {
        let space: SpaceID
        switch identity {
        case .layer(let layer):
            return L(
                "space_bar.item.ax.layer",
                "Shortcut layer %1$@",
                layer
            )
        case .space(let id):
            space = id
        }
        let windows =
            collapse?.windows
            ?? apps.reduce(0) { $0 + $1.count } + overflow
        let name = spaceName(space, windows: windows)
        return isActive
            ? L(
                "space_bar.item.ax.current",
                "%1$@, current",
                name
            )
            : L(
                "space_bar.item.ax.not_current",
                "%1$@, not current",
                name
            )
    }
}
