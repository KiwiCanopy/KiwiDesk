import CoreGraphics
import Foundation

/// The doors a state change (#2676) holds its window's ring
/// through: floating and back, maximizing and back, after the
/// write, so only a window our spring now moves is held; and a
/// take-out, whose held write lands with the brief pocket (#2680).
extension KiwiCore {
    /// A take-out's ring waits for its held write: armed now and
    /// settled when the plate lands, `lands` seconds from now.
    func holdRingThroughLanding(
        _ id: WindowID,
        target: CGRect,
        lands: TimeInterval
    ) {
        borders.holdStateChange(of: id, target: target)
        DispatchQueue.main.asyncAfter(deadline: .now() + lands) {
            [weak self] in
            self?.borders.stateChangeSettled(id)
        }
    }

    func holdRingForStateChange(_ id: WindowID) {
        guard tiler.animation.isAnimating(window: id) else { return }
        borders.holdStateChange(
            of: id,
            target: tiler.commandedFrame(of: id)
        )
    }
}
