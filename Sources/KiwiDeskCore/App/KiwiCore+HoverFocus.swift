import AppKit
import Foundation

/// Hover focus (`mouse.hover_focus`, #1869): the window the
/// pointer comes to rest on takes the focus a click would give
/// it — through the focus command, so its report arrives intended
/// rather than as the clickless focus #1161 bounces, and raised
/// like any commanded focus. The trigger is `PointerRest`, which
/// only user motion arms.
extension KiwiCore {
    /// Focuses the tracked window under a resting pointer
    /// (`cocoaPoint`, Cocoa screen space). `armedFocus` is the
    /// focus when the dwell armed: a focus moved since by
    /// anything else — a shortcut, ⌘-Tab — stands. Never warps:
    /// the pointer is the cause.
    func focusUnderRestingPointer(
        at cocoaPoint: CGPoint,
        armedFocus: WindowID?
    ) {
        guard tiler.settings.mouse.hoverFocus,
            !mouse.anyButtonHeld,
            focusedWindowID == armedFocus,
            wallClock().timeIntervalSince(lastDesktopSwitch)
                > DesktopSwitch.settle,
            let target = hoverTarget(at: GeometryUtils.axPoint(cocoaPoint))
        else { return }
        let front = frontmostPIDProvider?()
        let before = focusedWindowID
        withUserMotion {
            if target.own {
                // Settings, the one own window that tiles: its raise
                // is the GUI's door, Core's focus then `forceFront`
                // (#1281), on the screen it sits on.
                if target.space != state.workspaces.activeSpace {
                    applyFocusedSpaceSwitch(to: target.space)
                }
                uiBridge.onOpenSettings()
            } else if target.space == state.workspaces.activeSpace {
                focusWindow(target.id, warp: false)
            } else {
                // Another screen, as a click there (#446): the
                // follow's hand-off, then the switch's own retile.
                // Its Space is shown, so nothing was stashed (#1727).
                handFollowFocus(to: target.id, in: target.space, warp: false)
                spaceSwitchRetile(asSwitch: true)
            }
        }
        hoverRecordingFlight(from: front, before: before)
        onLog("hover focus: w\(target.id.raw)")
    }

    /// The window hover focus would focus at `point` (AX space),
    /// the shown Space it renders in, and whether it is KiwiDesk's
    /// own (the Settings window, whose raise has its one door) —
    /// nil where nothing is owed: something other than a tracked
    /// window is in front there (a menu, the Dock, a bar, a
    /// panel), the window already holds the focus, sits in no
    /// shown Space, is full screen, or its focus would move a
    /// window of that Space — a scrolling pan, a monocle flip —
    /// under a resting hand.
    func hoverTarget(
        at point: CGPoint
    ) -> (id: WindowID, space: SpaceID, own: Bool)? {
        // No tracked window there: skip the WindowServer read.
        guard state.windows.all.contains(where: { $0.frame.contains(point) })
        else { return nil }
        let own = getpid()
        guard
            let front = frontStack().first(where: {
                $0.frame.contains(point)
                    && !($0.pid == own
                        && Self.ignoresPointer(number: Int($0.number)))
            }),
            let window = state.windows[WindowID(front.number)],
            !window.isFullscreen,
            let space = state.stickyRenderSpace(of: window)
                ?? state.workspaces.space(of: window.id),
            state.workspaces.visibleSpaces.contains(space)
        else { return nil }
        if space == state.workspaces.activeSpace,
            let active = activeSpace,
            state.focusAnchor(of: active) == window.id,
            frontmostOwns(pid: window.pid)
        {
            return nil
        }
        guard !focusMovesWindows(window.id, in: space) else {
            return nil
        }
        return (window.id, space, front.pid == own)
    }

    /// Whether focusing `id` would move any window the layouts
    /// place — the same `placedFrames` reading
    /// `scrollTargetIsRevealed` takes, over a copy of the state with
    /// the focus written where `focusWindow` writes it: the HOME
    /// Space, so a sticky traveler's render Space anchors on it.
    private func focusMovesWindows(
        _ id: WindowID,
        in space: SpaceID
    ) -> Bool {
        // Activated alike, so only the focus's own effect counts.
        var base = state
        base.workspaces.activate(space)
        var probe = base
        probe.workspaces.focus(
            id,
            in: state.workspaces.space(of: id) ?? space
        )
        let now = tiler.placedFrames(state: base, recording: false)
        let then = tiler.placedFrames(state: probe, recording: false)
        guard Set(now.keys) == Set(then.keys) else { return true }
        return now.contains { window, frame in
            then[window].map { !TilingEngine.close(frame, to: $0) }
                ?? true
        }
    }

    /// An own overlay the pointer passes through — a ring, a
    /// mark, a cue, the KiwiVision plate — rather than a window it
    /// rests on.
    private static func ignoresPointer(number: Int) -> Bool {
        EventLoop.ownWindow(number: number)?.ignoresMouseEvents
            == true
    }
}
