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
        guard tiler.settings.mouseResize == .layout,
            let screen = NSScreen.main
                ?? NSScreen.screens.first
        else {
            retile(
                animated: tiler.settings.animations.onWindowResize
            )
            focusWindow(id)
            return
        }
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        // Everything below resolves against the active space's
        // params (#17): base value, master classification, and
        // the write target all follow the space's own override,
        // never the global — so a resize can't shift other spaces.
        let stack = tiler.settings.resolvedStack(for: space.id)
        let isMaster =
            (tiled.firstIndex(of: id) ?? .max) < stack.masterCount
        let adjustment = MouseResize.translate(
            mode: space.mode,
            isMaster: isMaster,
            slot: slot,
            frame: frame,
            bounds: GeometryUtils.axVisibleFrame(of: screen)
        )
        switch adjustment {
        case .bspRatio(let delta):
            let base =
                tiler.settings.resolvedBsp(for: space.id).splitRatio
            tiler.settings.setSplitRatio(
                min(max(base + delta, 0.1), 0.9),
                for: space.id
            )
        case .masterRatio(let delta):
            tiler.settings.setMasterRatio(
                min(max(stack.masterRatio + delta, 0.1), 0.9),
                for: space.id
            )
        case .scrollWidth(let delta):
            // Resize grows the slot by a pt delta: take the current
            // magnitude (a stored pt as-is; auto/% seeded against
            // the scroll axis), add the delta, store as points.
            let scrolling =
                tiler.settings.resolvedScrolling(for: space.id)
            let horizontal = scrolling.barAxisIsHorizontal
            let bounds = GeometryUtils.axVisibleFrame(of: screen)
            let along = horizontal ? bounds.width : bounds.height
            let current = scrolling.slotSize
                .editablePoints(along: along, horizontal: horizontal)
            tiler.settings.setSlotSize(
                .points(clamping: current + delta),
                for: space.id
            )
        case nil:
            break
        }
        retile(
            animated: tiler.settings.animations.onWindowResize
        )
        focusWindow(id)
    }
}
