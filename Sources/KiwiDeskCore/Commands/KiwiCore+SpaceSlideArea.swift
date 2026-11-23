import AppKit
import Foundation

/// The Space slide on a split screen (#3517 ruling 8): a switch in
/// one area slides that area alone, across its own Space Bar's
/// edge, and leaves the screen's other areas as they stand.
extension KiwiCore {
    /// The page `space`'s slide plays on, in AX coordinates: its
    /// area's part of `screen` where the screen is split, else the
    /// whole screen. The full frame, as the unsplit slide's, so the
    /// plates cover what the area's windows cover.
    func slidePage(of space: SpaceID, on screen: NSScreen) -> CGRect {
        let whole = GeometryUtils.flip(
            screen.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        guard let id = state.workspaces.placement(of: space),
            state.workspaces.placements(of: id.display).count > 1,
            let area = state.workspaces[placement: id]
        else { return whole }
        let rect = area.area.rect
            .offsetBy(dx: whole.minX, dy: whole.minY)
            .intersection(whole)
        return rect.isNull || rect.isEmpty ? whole : rect
    }

    /// The axis `space`'s slide plays along: across the Space Bar's
    /// edge as its area has it, else as its screen has it.
    func spaceSlideAxis(
        of space: SpaceID,
        on display: DisplayID
    ) -> SpaceSlidePlan.Axis {
        guard let id = state.workspaces.placement(of: space) else {
            return spaceSlideAxis(on: display)
        }
        return SpaceSlidePlan.axis(
            spaceBarEdge: tiler.settings.onScreen(areaKey(of: id))
                .spaceBarStyle.edge
        )
    }
}
