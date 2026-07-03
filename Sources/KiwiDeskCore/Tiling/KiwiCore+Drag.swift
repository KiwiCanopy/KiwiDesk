import CoreGraphics
import Foundation

/// Drop resolution for user window drags.
extension KiwiCore {
    /// Drop over another window's layout slot: the two windows
    /// swap positions and everything readjusts. Drop anywhere
    /// else: the window snaps back to its own slot.
    func handleDragEnd(_ id: WindowID, frame: CGRect) {
        guard let space = activeSpace,
            space.mode != .floating,
            space.windows.contains(id),
            state.windows[id]?.isFloating == false
        else { return }

        let slots = tiler.calculatedFrames(state: state)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let target = slots.first { entry in
            entry.key != id && entry.value.contains(center)
        }?.key

        if let target {
            state.workspaces.withSpace(space.id) {
                $0.swap(id, target)
            }
        }
        // Applies the swap — or, without a target, animates
        // the dragged window back into its slot.
        retile()
    }
}
