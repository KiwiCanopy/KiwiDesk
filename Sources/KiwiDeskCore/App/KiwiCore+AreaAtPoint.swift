import AppKit
import CoreGraphics

/// The area under a point (#3517): what a pointer-driven reader — a
/// drag, a drop, a click, a scroll gesture — asks instead of the
/// screen, so a split screen answers with the area the pointer is
/// in and an unsplit one with its one area.
extension KiwiCore {
    /// The placement of `display` an AX `point` falls in, judged on
    /// each area's whole rect — menu bar and Dock strip included —
    /// else the nearest; nil on an unsplit screen.
    func areaPlacement(
        atAX point: CGPoint,
        on display: DisplayID
    ) -> PlacementID? {
        let areas = state.workspaces.placements(of: display)
        guard areas.count > 1,
            let screen = TilingEngine.screen(for: display)
        else { return nil }
        let whole = tiler.screenFrameAX(screen)
        let rects = areas.map { area in
            (
                area.id,
                area.area.rect.offsetBy(dx: whole.minX, dy: whole.minY)
            )
        }
        if let hit = rects.first(where: { $0.1.contains(point) }) {
            return hit.0
        }
        return rects.min {
            Self.distance(from: point, to: $0.1)
                < Self.distance(from: point, to: $1.1)
        }?.0
    }

    /// The placement a pointer reader on `display` acts on: the
    /// area under `point`, else the screen's lead area.
    func pointerPlacement(
        atAX point: CGPoint,
        on display: DisplayID
    ) -> PlacementID {
        areaPlacement(atAX: point, on: display)
            ?? state.workspaces.placementOrWhole(of: display)
    }

    /// The Space shown under an AX `point` on `display`: its area's
    /// on a split screen, the screen's otherwise.
    func shownSpace(
        atAX point: CGPoint,
        on display: DisplayID
    ) -> SpaceID? {
        guard let area = areaPlacement(atAX: point, on: display) else {
            return state.workspaces.activeSpace(on: display)
        }
        return state.workspaces.activeSpace(on: area)
    }

    /// The Space shown under an AX `point`, on whichever screen
    /// holds it — menu bar and Dock strip included.
    func shownSpace(atAX point: CGPoint) -> SpaceID? {
        GeometryUtils.display(at: point).flatMap {
            shownSpace(atAX: point, on: $0)
        }
    }

    private static func distance(
        from point: CGPoint,
        to rect: CGRect
    ) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }
}
