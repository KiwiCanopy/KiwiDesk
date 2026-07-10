import AppKit
import Foundation

/// The event flow: every `KiwiEvent` from the AX event loop
/// routes through `handle` — state first, then per-event side
/// effects, then the structural retile — plus the snapshot
/// restore that replays state after wake/unlock or a crash.
/// Split from `KiwiCore.swift` (wiring) for file size (§2).
extension KiwiCore {
    func handle(_ event: KiwiEvent) {
        // Closing or minimizing the focused window must hand
        // focus to the space's fallback window (state already
        // picks one; the AX raise below makes it real). The
        // gone-event payload needs the window's app and space
        // captured here too — state.apply removes both.
        var focusLost = false
        var goneApp: String? = nil
        var goneSpace: SpaceID? = nil
        if case .windowDestroyed(let id, _) = event {
            focusLost = activeSpace?.focused == id
            goneApp = state.windows[id]?.appName
            goneSpace = state.workspaces.space(of: id)
        }
        state.spawnPlacements = [
            .bsp: tiler.settings.bsp.newWindowPlacement,
            .stack: tiler.settings.stack.newWindowPlacement,
            .scrolling:
                tiler.settings.scrolling.newWindowPlacement,
            .grid: tiler.settings.grid.newWindowPlacement,
        ]
        state.spawnOverride = tiler.settings.placementOverride
        state.apply(event)
        var newlyCreatedWindow: WindowID? = nil
        switch event {
        case .displaysChanged:
            tiler.displaysChanged()
            handleMonitorChange()
            emitMonitorChange()
        case .windowFocused(let id):
            // Echo provenance (#152): an echo of KiwiDesk's own
            // raise must not supersede a newer pending raise under
            // fast key-repeat. If our last self-raise is echoing
            // while a different target's raise is already pending,
            // keep that raise and re-assert focus to it — the
            // stale echo (and the state focus StateCoordinator
            // just moved onto the echoed window) would otherwise
            // pan back to the superseded window. Consume/clear the
            // memo either way: the world has moved on.
            let selfEcho = id == lastSelfRaised
            lastSelfRaised = nil
            if selfEcho, let pending = pendingFocusRaise,
                pending != id
            {
                if let space = state.workspaces.space(of: pending) {
                    state.workspaces.focus(pending, in: space)
                }
                return
            }
            // A real focus echo (a user click mid-pan) or our own
            // echo with nothing newer pending supersedes the
            // deferred raise (#143): the OS already raised whatever
            // the user reached, and a stale raise firing after the
            // pan would steal focus back.
            pendingFocusRaise = nil
            emitFocusChange(id)
            // cmd+tab (or a click) can reach a window hidden
            // in an inactive virtual space; pull that space
            // forward instead of typing into a stashed window.
            // Deferred: app activation transiently re-reports
            // the app's OLD focused window right before a new
            // window opens — only follow if focus settles.
            if let space = state.workspaces.space(of: id),
                space != state.workspaces.activeSpace
            {
                scheduleFocusFollow(id)
            } else if activeSpace?.mode.isFocusDriven == true {
                retileWithScrollDuration()
            }
        case .windowCreated(let window):
            // A brand-new window supersedes a pending follow
            // of a hidden window (see above).
            deferred.cancel(.focusFollow)
            newlyCreatedWindow = window.id
            emitWindowCreated(window)
        case .windowMoved(let id, let frame):
            drag.windowMoved(id, frame: frame)
        case .windowResized(let id, let frame):
            // Resize gestures share the drag pipeline (same
            // settle debounce). Only mouse-driven resizes
            // count; apps resizing themselves are corrected
            // by the next retile. `validated` lets the
            // trailing events of a fast resize (classified
            // via the recent press near a slot edge) start
            // the gesture even after the release.
            if isResizeGesture(id) {
                drag.windowMoved(
                    id,
                    frame: frame,
                    validated: true
                )
            }
        case .windowDestroyed(let id, let wasMinimized):
            drag.cancel(id)
            dragOverlay.hideAll()
            if wasMinimized {
                emitWindowMinimized(
                    id,
                    app: goneApp,
                    space: goneSpace
                )
            } else {
                emitWindowDestroyed(
                    id,
                    app: goneApp,
                    space: goneSpace
                )
            }
        case .nativeSpaceChanged:
            handleNativeSpaceChange()
        default:
            break
        }
        if TilingEngine.shouldRetile(after: event) {
            retile(newlyCreatedWindow: newlyCreatedWindow)
        }
        // Only raise windows the app still lists: after a
        // native Space switch the fallback may live on the
        // previous desktop, and raising it would switch back.
        if focusLost, let next = activeSpace?.focused,
            eventLoop.isListed(next)
        {
            focusWindow(next)
        }
    }

    /// Re-applies a snapshot after wake/unlock, a crash, or a
    /// restart: space membership and order first (the array
    /// order is the layout order), then the raw frames. Frames
    /// go through the tiler's frame pipeline so the resulting
    /// AX echoes are not mistaken for user drags.
    func restore(_ snapshot: StateSnapshot) {
        state.adopt(snapshot)
        for record in snapshot.windows {
            tiler.setFrame(record.windowID, record.frame)
        }
        // Diagnostic: snapshot windows that are not tracked
        // yet stay out of their space until a reconcile finds
        // them (cold-AX startup scan, issue #21 follow-up).
        let missing = snapshot.windows.filter {
            state.windows[$0.windowID] == nil
        }.count
        if missing > 0 {
            onLog(
                "restore: \(missing) snapshot windows not "
                    + "tracked yet"
            )
        }
    }
}
