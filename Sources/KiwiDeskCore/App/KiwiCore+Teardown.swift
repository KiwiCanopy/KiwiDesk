import AppKit
import ApplicationServices
import CoreGraphics

/// Pure gather-target computation for KiwiDesk shutdown.
///
/// When KiwiDesk stops (quit or restart), remaining managed
/// windows are spread onto their owning display per the
/// configured `quit.layout` strategy (#197) so the desktop is
/// usable the moment the WM exits. All reachable windows land
/// on the single visible native Space (inactive-virtual-space
/// windows are parked at the peek corner on that same native
/// Space). One-shot teardown placement: no live management
/// after, and no cross-monitor pull.
public enum WindowGather {
    /// Returns a gather target for every tracked, tiled window.
    ///
    /// `primaryHeight` is `NSScreen.screens.first?.frame.height`
    /// (Cocoa coordinates), used to flip `Display.visibleFrame`
    /// into AX (top-left) coordinates. Windows whose space has
    /// no display assignment fall back to the display with the
    /// lowest raw ID (deterministic on multi-monitor). Floating
    /// windows and windows with a zero-size frame are excluded.
    ///
    /// Each display collects its own windows (space-iteration
    /// order) and sizes its own grid — see `QuitGridLayout`.
    ///
    /// NOTE — cross-Space scope (#70): this iterates
    /// `allSpaces`, which is correct because KiwiDesk keeps
    /// every managed window on the single visible native Space
    /// (inactive-virtual-space windows are parked off-screen at
    /// the peek corner). When #70 introduces true multi-native-
    /// Space windows, add an explicit native-Space filter here
    /// (cf. `eventLoop.isListed`) or this will silently move
    /// background-Space windows.
    /// One display's gather group: every eligible window on
    /// it, in space-iteration order, plus its AX-flipped
    /// visible frame.
    public struct Group {
        public let display: DisplayID
        public let axFrame: CGRect
        public let windows: [WindowID]
    }

    /// The state walk, separated from the placement math so
    /// the quit path can log exactly what it grouped: every
    /// display with at least one eligible window, each with
    /// its full per-display window list (grid dimension
    /// depends on that total — spaces on one display MUST
    /// merge into one group, never grid separately).
    public static func collect(
        state: StateCoordinator,
        primaryHeight: CGFloat
    ) -> [Group] {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return [] }
        // Lowest raw ID → deterministic fallback on multi-
        // monitor; Array(dict.values) order is not stable.
        let fallback = displays.min { $0.id.raw < $1.id.raw }!
        var order: [DisplayID] = []
        var gathered: [DisplayID: [WindowID]] = [:]
        var axFrames: [DisplayID: CGRect] = [:]
        for space in state.workspaces.allSpaces {
            let displayID =
                state.workspaces.display(of: space.id)
            let display =
                displays.first { $0.id == displayID }
                ?? fallback
            if axFrames[display.id] == nil {
                order.append(display.id)
                axFrames[display.id] = GeometryUtils.flip(
                    display.visibleFrame,
                    primaryHeight: primaryHeight
                )
            }
            for windowID in space.windows {
                guard
                    let window = state.windows[windowID],
                    !window.isFloating,
                    window.frame.size != .zero
                else { continue }
                gathered[display.id, default: []]
                    .append(windowID)
            }
        }
        return order.compactMap { id in
            guard
                let windows = gathered[id],
                let axFrame = axFrames[id]
            else { return nil }
            return Group(
                display: id,
                axFrame: axFrame,
                windows: windows
            )
        }
    }

    public static func targets(
        state: StateCoordinator,
        primaryHeight: CGFloat,
        style: QuitLayoutStyle,
        minSize: CGFloat,
        targetDepth: Int
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        for group in collect(
            state: state,
            primaryHeight: primaryHeight
        ) {
            switch style {
            case .grid:
                result.merge(
                    QuitGridLayout.frames(
                        for: group.windows,
                        in: group.axFrame,
                        minSize: minSize,
                        targetDepth: targetDepth
                    )
                ) { current, _ in current }
            }
        }
        return result
    }
}

extension KiwiCore {
    /// Moves each managed tiled window onto its owning monitor,
    /// arranged per `quit.layout` within the display's visible
    /// area, so windows are not stranded in tiled frames after
    /// KiwiDesk exits.
    ///
    /// Two passes. `moveGatheredWindows` applies frames
    /// synchronously (direct AX IPC) inside a SkyLight
    /// display-suppression bracket so they composite as one
    /// visual update; `restackForTeardown` then raises the grid's
    /// circle, deliberately outside that bracket. A system-wide
    /// AX messaging timeout (0.25 s) is set once before the move
    /// loop and bounds every AX call in both passes — EUI reads,
    /// EUI disable/restore, setFrame and the raises — so
    /// Electron/WebKit apps (up to ~6 s with the default timeout)
    /// cannot stall the quit path; wall-clock budgets (~1 s for
    /// the moves, ~1 s for the raise circle) cap the worst case
    /// across all windows.
    ///
    /// Called on quit and restart, at the top of `stop()` while
    /// the event loop and AX subsystem are still live. When
    /// called due to AX permission revocation, `setFrame` calls
    /// return `kAXErrorAPIDisabled` and are silent no-ops —
    /// windows stay wherever the WM left them.
    func gatherWindows() {
        guard eventLoop.isRunning else { return }
        let primaryH = GeometryUtils.primaryHeight
        // Snapshot once: frames and the raise circle below MUST
        // partition identically (shared `buckets`), so both read
        // this local, not the settings, making the invariant
        // structural rather than relying on nothing mutating
        // between the two reads.
        let targetDepth = tiler.settings.quitGridTargetDepth
        // Diagnostic trail for the one-shot placement: a
        // wrong grid shape at quit is unreproducible after
        // the fact, so log what was grouped where.
        let groups = WindowGather.collect(
            state: state,
            primaryHeight: primaryH
        )
        onLog(
            "gatherWindows: \(groups.count) display group(s): "
                + groups.map {
                    "display \($0.display.raw) → "
                        + "\($0.windows.count) window(s) in "
                        + "\(Int($0.axFrame.width))×"
                        + "\(Int($0.axFrame.height))"
                }.joined(separator: "; ")
        )
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: primaryH,
            style: tiler.settings.quitLayout,
            minSize: tiler.settings.minWindowSize,
            targetDepth: targetDepth
        )
        guard !frames.isEmpty else { return }
        // The bracket covers the MOVES ONLY, and the `do` scope is
        // what bounds it: the raise circle below used to run inside
        // it too, which cost nothing while it was a bare loop
        // issuing raises in a few ms, but the drain that replaced
        // it waits for each landing (#688) — up to its whole 1 s
        // budget. `SLSDisableUpdate` freezes compositing for the
        // entire desktop, so holding it across those waits would
        // freeze the screen for the wait rather than for the
        // moves. Resuming first costs one extra composite, and
        // the restack does not need the bracket: it reads the
        // WindowServer's ordering, which the bracket never
        // suppressed (probe, 2026-08-03 — see
        // `restackForTeardown`).
        moveGatheredWindows(frames)
        restackForTeardown(
            groups: groups,
            frames: frames,
            targetDepth: targetDepth
        )
    }

    /// Applies the gather frames as one visual update, inside the
    /// display-suppression bracket.
    private func moveGatheredWindows(
        _ frames: [WindowID: CGRect]
    ) {
        SkyLight.suppressDisplay()
        // defer ensures resumeDisplay() runs even if the
        // budget fires a break below.
        defer { SkyLight.resumeDisplay() }
        let deadline = Date().addingTimeInterval(1.0)
        // Bound every AX call — EUI reads, EUI disable/
        // restore, setFrame — including on fresh app elements
        // created inside AXHelper. The system-wide default
        // covers all elements created after this point.
        AXUIElementSetMessagingTimeout(
            AXUIElementCreateSystemWide(),
            0.25
        )
        for (id, frame) in frames {
            // Wall-clock budget: one unresponsive cluster of
            // apps cannot freeze the entire quit path.
            if Date() > deadline {
                onLog(
                    "gatherWindows: 1 s budget exceeded"
                        + " (targeted \(frames.count) windows)"
                )
                break
            }
            guard
                let element = eventLoop.element(for: id)
            else {
                onLog(
                    "gatherWindows: no AX element for window "
                        + "\(id.raw) — left in place"
                )
                continue
            }
            // Mirror applyInstant's EUI bracket: EUI-on apps
            // self-animate frame changes (Electron/WebKit) and
            // can clamp or swallow the set — drop it for the
            // move and restore whatever it was.
            var pid: pid_t = 0
            let hasPid =
                AXUIElementGetPid(element, &pid) == .success
            let wasEUI =
                hasPid
                && AXHelper.getEnhancedUserInterface(
                    pid: pid
                ) == true
            if wasEUI {
                AXHelper.setEnhancedUserInterface(
                    pid: pid,
                    enabled: false
                )
            }
            WindowControl.setFrame(frame, of: element)
            if wasEUI {
                AXHelper.setEnhancedUserInterface(
                    pid: pid,
                    enabled: true
                )
            }
        }
    }
}
