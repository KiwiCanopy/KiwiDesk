import AppKit
import CoreGraphics
import Foundation

/// Where "mouse follows focus" (#186) warps to, as pure
/// geometry so it stays unit-testable: the target frame's
/// center, or nil when no warp should happen — an empty
/// frame, or the cursor already inside it. The inside check
/// doubles as the self-warp guard: a same-window re-focus or
/// a click on the window under the pointer never moves a
/// pointer that is already where it belongs.
enum MouseWarp {
    static func target(
        frame: CGRect,
        cursor: CGPoint?
    ) -> CGPoint? {
        guard !frame.isEmpty else { return nil }
        if let cursor, frame.contains(cursor) {
            return nil
        }
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}

extension KiwiCore {
    /// The guard chain before any warp geometry (#186), split
    /// out so tests can pin it without CoreGraphics moving the
    /// real pointer: the toggle, any held mouse button (the
    /// user is mid-click or mid-drag — yanking the pointer
    /// would hijack the gesture, and a mouse-made focus change
    /// needs no warp anyway), an in-flight z-order restore
    /// (whose pile raises steal focus without user intent),
    /// and the active space (a focus landing on a stashed
    /// window has no on-screen frame worth warping to — the
    /// deferred focus follow warps once the space is pulled
    /// forward).
    func mouseWarpEligible(_ id: WindowID) -> Bool {
        tiler.settings.mouse.followsFocus
            && NSEvent.pressedMouseButtons == 0
            && zOrderRestoresInFlight == 0
            && state.workspaces.space(of: id)
                == state.workspaces.activeSpace
    }

    /// Warps the pointer to the newly-focused window when
    /// `mouse.follows_focus` is on (#186). Called from the
    /// focus-intent points — `focusWindow` (keyboard focus,
    /// close fallback, space switches) and the deferred focus
    /// follow — and, for focus changes KiwiDesk did not make
    /// itself (cmd+tab, app-driven focus), from the
    /// `.windowFocused` handler. The event loop never observes
    /// KiwiDesk's own process (#174) or unmanaged windows, so
    /// no extra filter is needed here.
    ///
    /// Tiled windows warp to the layout's *assigned* slot, not
    /// the live AX frame: in focus-driven layouts (scrolling,
    /// monocle) the window is still sliding when the warp
    /// runs, and the AX frame would be a stale mid-flight
    /// position. Floating windows have no slot and fall back
    /// to the AX frame (one snapshot, not a loop — §5). Both
    /// are top-left global coordinates, the space
    /// `CGWarpMouseCursorPosition` expects.
    func warpMouseToFocused(_ id: WindowID) {
        guard mouseWarpEligible(id) else { return }
        let frame: CGRect
        if let slot = tiler.calculatedFrames(
            state: state
        )[id] {
            frame = slot
        } else if let element = eventLoop.element(for: id) {
            frame = AXHelper.frame(of: element)
        } else {
            return
        }
        guard
            let target = MouseWarp.target(
                frame: frame,
                cursor: CGEvent(source: nil)?.location
            )
        else { return }
        CGWarpMouseCursorPosition(target)
        // A programmatic warp decouples the hardware mouse for
        // the local-events suppression interval (~250 ms) —
        // a dead mouse right when "the next click lands where
        // the keyboard works" is the whole point. Re-associate
        // immediately so the pointer is live.
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
