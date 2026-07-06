import AppKit
import Foundation

/// Directional `focus` / `swap` navigation, split out of
/// `KiwiCore+Commands` for file size.
extension KiwiCore {
    func navigate(
        _ args: [JSONValue],
        swapping: Bool
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = Direction(rawValue: raw)
        else {
            return .fail("expected left|right|up|down")
        }
        guard let space = activeSpace,
            let focused = space.focused
        else {
            return .fail("no focused window")
        }
        // Monocle windows all share one frame, so geometric
        // neighbor search finds nothing. Directions on the
        // configured orientation axis cycle the window order
        // instead; the cross axis falls through.
        if space.mode == .monocle,
            let response = monocleCycle(
                direction,
                space: space,
                focused: focused,
                swapping: swapping
            )
        {
            return response
        }
        // Navigate the layout's slots, not live AX frames:
        // live frames are stale mid-animation or when an app
        // misses a move notification, and cascaded windows
        // overlap anyway. Floating windows (no slot) fall
        // back to their last known frame.
        let slots = tiler.calculatedFrames(state: state)
        guard
            let frame = slots[focused]
                ?? state.windows[focused]?.frame
        else {
            return .fail("no focused window")
        }
        let candidates = space.windows
            .filter {
                $0 != focused
                    && state.windows[$0]?.isFloating == false
            }
            .compactMap { id -> (WindowID, CGRect)? in
                guard
                    let slot = slots[id]
                        ?? state.windows[id]?.frame
                else { return nil }
                return (id, slot)
            }
        guard
            let target = Navigation.neighbor(
                from: frame,
                in: direction,
                candidates: candidates
            )
        else {
            return .fail("no window \(raw) of focus")
        }
        if swapping {
            let crossedZones = crossesStackBoundary(
                focused,
                target,
                in: space
            )
            state.workspaces.withSpace(space.id) {
                $0.swap(focused, target)
            }
            retile(
                animated: tiler.settings.animations.onWindowSwap
            )
            if crossedZones {
                scheduleZOrderRestore()
            }
        } else {
            focusWindow(target)
        }
        return .ok()
    }
}
