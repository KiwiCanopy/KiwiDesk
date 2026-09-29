import AppKit

/// A collapsed Space item (#1683) and what every Space item
/// announces, split from `SpaceBarItemView` for the file size.
extension SpaceBarItemView {
    /// A collapsed Space item
    /// (`SpaceBarOverlay.Item.collapsed(to:)`): the identifier
    /// alone, its window count a disc on the identifier's corner
    /// rather than a cell of its own, so the item is the
    /// identifier's length. None draws no disc, and the
    /// identifier in `emptyItemColor`.
    struct Collapse: Equatable {
        /// The windows the Space holds, drawn and announced.
        let windows: Int

        /// The disc's text: past `discCap` it reads "9+" so the
        /// mark stays a disc; the label announces the exact count.
        var discText: String {
            windows > Self.discCap
                ? "\(Self.discCap)+" : "\(windows)"
        }

        static let discCap = 9
    }

    /// The windows this item's Space holds, collapsed or not —
    /// what the label announces and the empty ink asks.
    var heldWindows: Int {
        collapse?.windows
            ?? apps.reduce(0) { $0 + $1.count } + after.windows.count
            + before.windows.count
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
        let name = spaceName(space, windows: heldWindows)
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
