import AppKit
import Foundation

/// The Space slide on a split screen (#3517 ruling 8): a switch in
/// one area slides that area alone, across its own Space Bar's
/// edge, and leaves the screen's other areas as they stand.
extension KiwiCore {
    /// The page `space`'s slide plays on, in AX coordinates: its
    /// area's part of `screen` where the screen is split, else the
    /// whole screen, read through the shelf's one `cocoaFrame`.
    func slidePage(of space: SpaceID, on screen: NSScreen) -> CGRect {
        let frame =
            state.workspaces.placement(of: space)
            .flatMap { state.workspaces[placement: $0] }
            .map { cocoaFrame(of: $0, on: screen) } ?? screen.frame
        return GeometryUtils.flip(
            frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
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
            spaceBarEdge: settings(on: id).spaceBarStyle.edge
        )
    }
}
