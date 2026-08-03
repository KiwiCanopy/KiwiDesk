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
        // 1 pt of slack: `contains` excludes the max edges,
        // and a pointer parked exactly on a border (fresh
        // from an edge resize) is "inside" for this purpose.
        if let cursor,
            frame.insetBy(dx: -1, dy: -1).contains(cursor)
        {
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
    /// needs no warp anyway), and the active space (a focus
    /// landing on a stashed window has no on-screen frame
    /// worth warping to — the deferred focus follow warps once
    /// the space is pulled forward). The in-flight restore
    /// hold is NOT part of this chain since #689: it defers a
    /// warp rather than refusing one, so `warpMouseToFocused`
    /// owns it.
    func mouseWarpEligible(_ id: WindowID) -> Bool {
        tiler.settings.mouse.followsFocus
            && NSEvent.pressedMouseButtons == 0
            && (state.workspaces.space(of: id)
                == state.workspaces.activeSpace
                // A sticky window is visible on EVERY space
                // (#414): its foreign home is not "stashed
                // off-screen", the traveler's slot is right
                // there — so the pointer follows it too.
                || state.windows[id]?.isSticky == true)
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
    /// A restore in flight HOLDS the warp rather than dropping
    /// it (#186's guard, #689's fix): the pile raises churn
    /// focus without user intent, so the pointer must not
    /// chase them — but the focus change that landed mid-drain
    /// is real, and before #689 its warp was lost outright
    /// (#684 stretched the drain from ~10 ms to 50-400 ms,
    /// which made that loss routine). The pending slot re-fires
    /// on the last drain's end, staleness-checked.
    ///
    /// Tiled windows warp to the layout's *assigned* slot, not
    /// the live AX frame: in focus-driven layouts (scrolling,
    /// monocle) the window is still sliding when the warp
    /// runs, and the AX frame would be a stale mid-flight
    /// position. Floating windows have no slot and fall back
    /// to the AX frame (one snapshot, not a loop — §5). Both
    /// are top-left global coordinates, the space the pointer
    /// warp expects.
    func warpMouseToFocused(_ id: WindowID) {
        guard mouseWarpEligible(id) else { return }
        guard zOrderRestoresInFlight == 0 else {
            // Hold only CLICKLESS intent (cmd-tab, keyboard
            // focus-nav) — the case whose warp the drain
            // genuinely loses (#689). A fresh left press means
            // the mouse made this focus change (a bar click's
            // intent warp lands here whenever the previous
            // jump's restore is still draining), and a held
            // warp firing hundreds of ms after the click reads
            // as a spurious pointer jump (device QA,
            // 2026-08-03); dropping it is the pre-#689
            // behavior, and the pointer already sits where the
            // user's hand put it. The trade: keyboard nav
            // within ~1 s of a press, mid-drain, loses its
            // warp too — pre-#689 every such warp was lost.
            let now = Date()
            let mouseMade =
                lastLeftClick.map {
                    now.timeIntervalSince($0.at)
                        < Self.selfRaiseSiblingWindow
                } == true
            if !mouseMade {
                pendingMouseWarp = id
            }
            return
        }
        pendingMouseWarp = nil
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
        pointerWarp?(frame)
    }

    /// Fires the warp a draining restore held, once the LAST
    /// overlapping drain ends (#689) — called by
    /// `performZOrderSequence` after its counter drop. Fire-time
    /// re-validation, the `runPendingFocusRaise` pattern: a
    /// pending target the focus has moved off is dropped, not
    /// warped. A held sticky-traveler warp is dropped too
    /// (`activeSpace.focused` never holds a traveler, #431) —
    /// conservative, and still strictly more than the
    /// pre-#689 behavior of dropping every held warp.
    func runPendingMouseWarp() {
        guard zOrderRestoresInFlight == 0,
            let id = pendingMouseWarp
        else { return }
        pendingMouseWarp = nil
        guard id == activeSpace?.focused else { return }
        warpMouseToFocused(id)
    }
}
