import AppKit
import CoreGraphics
import Foundation

/// Mouse-resize resolution: classifying resize events and
/// applying a finished resize gesture to the layout. The
/// gesture itself travels through the drag pipeline (see
/// KiwiCore+Drag), which calls handleResizeEnd on drop.
extension KiwiCore {
    /// Whether a resized event belongs to a mouse gesture:
    /// the button is still down, or it is the trailing AX
    /// event of a fast resize — released moments ago, with
    /// the press having started near the window's slot edge
    /// (where resize drags begin; app-initiated resizes like
    /// a zoom button don't match).
    func isResizeGesture(_ id: WindowID) -> Bool {
        if NSEvent.pressedMouseButtons & 1 == 1 {
            return true
        }
        guard let press = mouse.press,
            let up = press.upAt,
            Date().timeIntervalSince(up) < 1,
            let slot = tiler.calculatedFrames(
                state: state
            )[id]
        else { return false }
        return MouseResize.nearEdge(
            press.location,
            of: slot
        )
    }

    /// Mouse resize of a tiled window, applied on release:
    /// translate the size delta into the same layout change
    /// the `resize` command makes (neighbors give or take
    /// space). Layouts without a parameter for the resized
    /// axis — and snap_back mode — animate the window back.
    func handleResizeEnd(
        _ id: WindowID,
        slot: CGRect,
        frame: CGRect,
        in space: Space
    ) {
        guard tiler.mouseResize == .layout,
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else {
            retile()
            focusWindow(id)
            return
        }
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        let isMaster =
            (tiled.firstIndex(of: id) ?? .max)
            < tiler.settings.stack.masterCount
        let adjustment = MouseResize.translate(
            mode: space.mode,
            isMaster: isMaster,
            slot: slot,
            frame: frame,
            bounds: GeometryUtils.axVisibleFrame(of: screen)
        )
        switch adjustment {
        case .bspRatio(let delta):
            let ratio = tiler.settings.bsp.splitRatio + delta
            tiler.settings.bsp.splitRatio =
                min(max(ratio, 0.1), 0.9)
        case .masterRatio(let delta):
            let ratio =
                tiler.settings.stack.masterRatio + delta
            tiler.settings.stack.masterRatio =
                min(max(ratio, 0.1), 0.9)
        case .scrollWidth(let delta):
            // Resize grows the slot by a pt delta: resolve the
            // current size (auto/% → pt) against the scroll axis,
            // then store the result as absolute points.
            let horizontal =
                tiler.settings.scrolling.barAxisIsHorizontal
            let bounds = GeometryUtils.axVisibleFrame(of: screen)
            let along = horizontal ? bounds.width : bounds.height
            let current = tiler.settings.scrolling.slotSize
                .resolved(along: along, horizontal: horizontal)
            tiler.settings.scrolling.slotSize =
                .points(max(current + delta, 100))
        case nil:
            break
        }
        retile()
        focusWindow(id)
    }
}
