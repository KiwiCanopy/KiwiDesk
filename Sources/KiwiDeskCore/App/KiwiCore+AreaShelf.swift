import AppKit

/// The shelves of one area (#3517 ruling 30): each area of a split
/// screen draws its own App Bar and Space Bar for the Space it
/// shows, measured on its own frame; an unsplit screen is its one
/// area. Every screen read stays physical (bars.md ▸ One shelf
/// panel per area and edge).
extension KiwiCore {
    /// The frame `placement`'s shelves are measured on, AX: the
    /// screen's `visible` frame, cut to the area's rect where the
    /// screen is split, so the menu bar, notch and Dock land on the
    /// area touching them (ruling 8) and a lower area's top bar sits
    /// on its own top edge.
    func shelfFrame(
        of placement: Placement,
        visible: CGRect,
        on screen: NSScreen
    ) -> CGRect {
        guard isSplit(placement.display) else { return visible }
        let whole = Self.axFrame(of: screen)
        let cut = visible.intersection(
            placement.area.rect.offsetBy(dx: whole.minX, dy: whole.minY)
        )
        return cut.isNull ? visible : cut
    }

    /// `placement`'s whole rect in Cocoa coordinates (y up): the
    /// screen's frame where it is not split.
    func cocoaFrame(of placement: Placement, on screen: NSScreen) -> CGRect {
        guard isSplit(placement.display) else { return screen.frame }
        let rect = placement.area.rect
        return CGRect(
            x: screen.frame.minX + rect.minX,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    /// Every screen's frame, Cocoa, a split screen's as its areas:
    /// what a hiding bar's edge is judged a crossing against, so an
    /// area's inner edge is no free edge (ruling 30).
    func shelfNeighbourFrames() -> [CGRect] {
        ScreenList.all.flatMap { screen -> [CGRect] in
            guard let id = screen.kiwiDisplayID, isSplit(id) else {
                return [screen.frame]
            }
            return state.workspaces.placements(of: id).map {
                cocoaFrame(of: $0, on: screen)
            }
        }
    }

    /// Whether `display` is split into more than one area.
    func isSplit(_ display: DisplayID) -> Bool {
        state.workspaces.placements(of: display).count > 1
    }

    /// The Space Bar's items on `placement` — the layer item
    /// leading — or nil when it has nothing to show there.
    func spaceBarContent(
        on placement: PlacementID,
        style: SpaceBarLook
    ) -> [SpaceBarOverlay.Item]? {
        withSpaceBarLayer(spaceBarItems(placement: placement, style: style))
    }

    /// The App Bar content for the Space `placement` shows, or nil
    /// when that Space hosts no non-empty bar.
    func appBarContent(
        on placement: PlacementID,
        settings: TilingSettings
    ) -> AppBarContent? {
        guard
            let id = state.workspaces.activeSpace(on: placement),
            let space = state.workspaces[id]
        else { return nil }
        return appBarContent(space: space, settings: settings)
    }
}
