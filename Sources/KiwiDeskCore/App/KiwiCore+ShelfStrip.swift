import AppKit

/// What one shelf shows and what a Space Bar holds, split from
/// `KiwiCore+Shelf.swift` at the §2.1 ceiling.
extension KiwiCore {
    /// One shelf to show: its area, edge and strip, which bars its
    /// plan placed on it, and the divider its arrangement set.
    struct ShelfStrip {
        let placement: PlacementID
        let edge: AppBarEdge
        let strip: CGRect
        let carriesSpace: Bool
        let carriesApp: Bool
        var divider: ShelfArrangement.Divider? = nil
        /// A shelf revealed onto an empty edge (#761, #2497), and
        /// the mark at `mark` a grow reveal grows out of.
        var slides = false
        var mark: BarMotion.RevealMark? = nil
        /// The pocket's pinned slot on this strip, AX (#2678).
        var pocketSlot: CGRect? = nil
    }

    /// The Space Bar's items on `display` — the layer item
    /// leading — or nil when it has nothing to show there; built
    /// whatever the bar's visibility, since a hidden bar's shortcut
    /// may show it (#761).
    func spaceBarContent(
        on display: DisplayID,
        style: SpaceBarLook
    ) -> [SpaceBarOverlay.Item]? {
        withSpaceBarLayer(spaceBarItems(display: display, style: style))
    }

    /// `items` with the layer item leading, or nil where there are
    /// none.
    func withSpaceBarLayer(
        _ items: [SpaceBarOverlay.Item]
    ) -> [SpaceBarOverlay.Item]? {
        var items = items
        guard !items.isEmpty else { return nil }
        // After the emptiness guard: a layer never draws a bar
        // on a screen with no Space item to lead.
        if let layer = spaceBarLayerItem() {
            items.insert(layer, at: 0)
        }
        return items
    }
}
