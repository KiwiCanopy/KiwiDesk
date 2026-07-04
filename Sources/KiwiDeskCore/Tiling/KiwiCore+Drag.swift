import AppKit
import CoreGraphics
import Foundation

/// Drop resolution for user window drags and resizes.
extension KiwiCore {
    /// Drop over another window's layout slot: the two windows
    /// swap positions and everything readjusts. Drop anywhere
    /// else: the window snaps back to its own slot. A drop
    /// that changed the window's SIZE is a resize gesture and
    /// adjusts the layout instead (see handleResizeEnd).
    func handleDragEnd(_ id: WindowID, frame: CGRect) {
        guard let space = activeSpace,
            space.mode != .floating,
            space.windows.contains(id),
            state.windows[id]?.isFloating == false
        else { return }

        let slots = tiler.calculatedFrames(state: state)
        if let slot = slots[id],
            MouseResize.isResize(from: slot, to: frame)
        {
            handleResizeEnd(
                id,
                slot: slot,
                frame: frame,
                in: space
            )
            return
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let target = slots.first { entry in
            entry.key != id && entry.value.contains(center)
        }?.key

        var crossedZones = false
        if let target {
            crossedZones = crossesStackBoundary(
                id,
                target,
                in: space
            )
            state.workspaces.withSpace(space.id) {
                $0.swap(id, target)
            }
        }
        // Applies the swap — or, without a target, animates
        // the dragged window back into its slot.
        retile()
        // The dropped window has the user's attention: make
        // it the focused one, in state and for real.
        focusWindow(id)
        if crossedZones {
            scheduleStackZOrderRestore()
        }
    }

    /// Mouse resize of a tiled window, applied on release:
    /// translate the size delta into the same layout change
    /// the `resize` command makes (neighbors give or take
    /// space). Layouts without a parameter for the resized
    /// axis — and snap_back mode — animate the window back.
    private func handleResizeEnd(
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
            let width =
                tiler.settings.scrolling.windowWidth + delta
            tiler.settings.scrolling.windowWidth =
                max(width, 100)
        case nil:
            break
        }
        retile()
        focusWindow(id)
    }
}
