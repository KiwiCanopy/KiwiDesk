import AppKit
import CoreGraphics
import Foundation

/// Where "mouse follows focus" (#186) warps to, as pure
/// geometry so it stays unit-testable: the target frame's
/// center, or nil when no warp should happen — an empty
/// frame, or the cursor already inside it. The inside check
/// doubles as the self-warp guard: a same-window re-focus or
/// the AX echo of KiwiDesk's own raise never moves a pointer
/// that is already where it belongs.
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
    /// Warps the pointer to the newly-focused window when
    /// `mouse.follows_focus` is on (#186). Called from the
    /// `.windowFocused` handler, after `emitFocusChange` — the
    /// event loop never observes KiwiDesk's own process (#174)
    /// or unmanaged windows, so no extra filter is needed here.
    ///
    /// Tiled windows warp to the layout's *assigned* slot, not
    /// the live AX frame: in focus-driven layouts (scrolling,
    /// monocle) the window is still sliding when the focus echo
    /// lands, and the AX frame would be a stale mid-flight
    /// position. Floating windows have no slot and fall back to
    /// the AX frame (one snapshot, not a loop — §5). Both are
    /// top-left global coordinates, the space
    /// `CGWarpMouseCursorPosition` expects.
    func warpMouseToFocused(_ id: WindowID) {
        guard tiler.settings.mouse.followsFocus else { return }
        // A held button means the user is mid-click or mid-drag
        // with the mouse itself — yanking the pointer would
        // hijack the gesture (and the focus change was
        // mouse-made anyway, so the pointer is already there).
        guard NSEvent.pressedMouseButtons & 1 == 0 else {
            return
        }
        // Only windows on the active space: a focus landing on
        // a stashed window (cmd+tab into an inactive virtual
        // space) has no on-screen frame worth warping to.
        guard
            state.workspaces.space(of: id)
                == state.workspaces.activeSpace
        else { return }
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
    }
}
