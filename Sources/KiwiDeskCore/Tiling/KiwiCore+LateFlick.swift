import CoreGraphics
import Foundation

/// The trailing-event reads of a float flick (#1798, #2087): which
/// moves inside the frame applier's echo grace answer the hand
/// rather than our own write. Floats only, per the #1798 ruling;
/// the trailing press both late gestures share,
/// `recentSinglePress`, stays with the drag.
extension KiwiCore {
    /// Whether a move arriving after the release is a fast
    /// flick's only event (#1798): a single press on the window
    /// released moments ago, and the window a float, so the late
    /// gesture runs the drop clamp and never a tile's swap. AX
    /// throttles moves, so a flick can report none while held. A
    /// move that also resized is a zoom, #1358's to correct.
    func isLateFlick(
        _ id: WindowID,
        frame: CGRect,
        previous: CGRect?
    ) -> Bool {
        guard !mouse.leftButtonHeld, !drag.hasGesture(id),
            let previous, frame.size == previous.size,
            let press = recentSinglePress ?? releaseInFlight,
            previous.contains(press.location),
            pressFollowsOwnWrite(press, id)
        else { return false }
        return dropLandsUnmanaged(id)
    }

    /// Whether a move while the button is still HELD answers the
    /// hand (#2087): a single press that began after our last
    /// write, on the window, and the window a float. The drag's
    /// echo guard would drop it as ours inside the grace, so a
    /// quick second flick opened no gesture.
    func isHeldFlick(
        _ id: WindowID,
        frame: CGRect,
        previous: CGRect?
    ) -> Bool {
        guard mouse.leftButtonHeld, let press = mouse.press,
            press.upAt == nil, press.clickCount < 2,
            let previous, frame.size == previous.size,
            drag.hasGesture(id) || previous.contains(press.location),
            pressFollowsOwnWrite(press, id)
        else { return false }
        return dropLandsUnmanaged(id)
    }

    /// A press whose release is in flight (#2087): the button reads
    /// up before its release is recorded. Bounded by the press's
    /// own age, the trailing window `recentSinglePress` keeps.
    private var releaseInFlight: MouseTracker.Press? {
        guard let press = mouse.press, press.upAt == nil,
            !mouse.leftButtonHeld, press.clickCount < 2,
            wallClock().timeIntervalSince(press.downAt) < 1
        else { return nil }
        return press
    }

    /// Whether `press` began after the engine's last frame-set of
    /// `id`: a move then answers the hand, never our write, so a
    /// second flick inside the echo grace still counts (#1798).
    private func pressFollowsOwnWrite(
        _ press: MouseTracker.Press,
        _ id: WindowID
    ) -> Bool {
        guard let setAge = tiler.secondsSinceSet(id) else { return true }
        return wallClock().timeIntervalSince(press.downAt) < setAge
    }
}
