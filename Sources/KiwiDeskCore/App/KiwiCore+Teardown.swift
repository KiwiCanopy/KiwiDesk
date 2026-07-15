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
    public static func targets(
        state: StateCoordinator,
        primaryHeight: CGFloat,
        style: QuitLayoutStyle,
        minSize: CGFloat
    ) -> [WindowID: CGRect] {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return [:] }
        // Lowest raw ID → deterministic fallback on multi-
        // monitor; Array(dict.values) order is not stable.
        let fallback = displays.min { $0.id.raw < $1.id.raw }!
        // Collect per display first: the grid dimension
        // depends on each display's total window count.
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
        var result: [WindowID: CGRect] = [:]
        for displayID in order {
            guard
                let windows = gathered[displayID],
                let axFrame = axFrames[displayID]
            else { continue }
            switch style {
            case .grid:
                result.merge(
                    QuitGridLayout.frames(
                        for: windows,
                        in: axFrame,
                        minSize: minSize
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
    /// Applies frames synchronously (direct AX IPC) inside a
    /// SkyLight display-suppression bracket so all moves
    /// composite as one visual update. A system-wide AX
    /// messaging timeout (0.25 s) is set once before the loop
    /// and bounds every AX call in the iteration — EUI reads,
    /// EUI disable/restore, and setFrame — so Electron/WebKit
    /// apps (up to ~6 s with the default timeout) cannot stall
    /// the quit path; a total wall-clock budget of ~1 s caps
    /// the worst case across all windows.
    ///
    /// Called on quit and restart, at the top of `stop()` while
    /// the event loop and AX subsystem are still live. When
    /// called due to AX permission revocation, `setFrame` calls
    /// return `kAXErrorAPIDisabled` and are silent no-ops —
    /// windows stay wherever the WM left them.
    func gatherWindows() {
        guard eventLoop.isRunning else { return }
        let primaryH = GeometryUtils.primaryHeight
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: primaryH,
            style: tiler.settings.quitLayout,
            minSize: tiler.settings.minWindowSize
        )
        guard !frames.isEmpty else { return }
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
            else { continue }
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
