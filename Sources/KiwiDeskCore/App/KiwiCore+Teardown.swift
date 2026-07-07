import AppKit
import ApplicationServices
import CoreGraphics

/// Pure gather-target computation for KiwiDesk shutdown.
///
/// When KiwiDesk stops (quit or restart), managed tiled
/// windows are staggered onto their owning display so they
/// are not left stranded in tiled frames after the WM exits.
/// All reachable windows land on the single visible native
/// Space (inactive-virtual-space windows are parked at the
/// peek corner on that same native Space).
///
/// **Floating-size decision**: KiwiDesk does not yet track a
/// "last-floating size" (no `lastFloatingSize` in state; see
/// issue #70). Gather keeps the window's current frame size —
/// the tiled size the AX echoes last reported — and places it
/// within the display's visible area. A future pass may record
/// pre-tile sizes for a richer restore.
public enum WindowGather {
    /// Diagonal step between staggered windows (pts).
    public static let staggerStep: CGFloat = 40

    /// Returns a staggered gather-target frame: `size`
    /// centered in `axFrame` with a diagonal `index × step`
    /// offset, each edge clamped inside `axFrame`.
    /// Index 0 produces the exact center.
    ///
    /// `axFrame` must be in AX (top-left-origin) coordinates;
    /// the returned rect is also in AX coordinates.
    public static func staggeredFrame(
        size: CGSize,
        in axFrame: CGRect,
        index: Int,
        step: CGFloat = staggerStep
    ) -> CGRect {
        let offset = CGFloat(index) * step
        let x = axFrame.midX - size.width / 2 + offset
        let y = axFrame.midY - size.height / 2 + offset
        let cx = max(
            axFrame.minX,
            min(x, axFrame.maxX - size.width)
        )
        let cy = max(
            axFrame.minY,
            min(y, axFrame.maxY - size.height)
        )
        return CGRect(
            x: cx,
            y: cy,
            width: size.width,
            height: size.height
        )
    }

    /// Returns a gather-target frame: `size` centered in
    /// `axFrame`, with each edge clamped inside `axFrame`.
    ///
    /// `axFrame` must be in AX (top-left-origin) coordinates;
    /// the returned rect is also in AX coordinates.
    public static func centeredFrame(
        size: CGSize,
        in axFrame: CGRect
    ) -> CGRect {
        staggeredFrame(size: size, in: axFrame, index: 0)
    }

    /// Returns a gather target for every tracked, tiled window.
    ///
    /// `primaryHeight` is `NSScreen.screens.first?.frame.height`
    /// (Cocoa coordinates), used to flip `Display.visibleFrame`
    /// into AX (top-left) coordinates. Windows whose space has
    /// no display assignment fall back to the display with the
    /// lowest raw ID (deterministic on multi-monitor). Floating
    /// windows and windows with a zero-size frame are excluded.
    ///
    /// Windows on the same display are staggered diagonally by
    /// `staggerStep` pts per window so each is at a distinct,
    /// findable position rather than an overlapping pile.
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
        primaryHeight: CGFloat
    ) -> [WindowID: CGRect] {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return [:] }
        // Lowest raw ID → deterministic fallback on multi-
        // monitor; Array(dict.values) order is not stable.
        let fallback = displays.min { $0.id.raw < $1.id.raw }!
        var result: [WindowID: CGRect] = [:]
        // Per-display stagger counter so each display's
        // windows cascade independently.
        var displayIdx: [DisplayID: Int] = [:]
        for space in state.workspaces.allSpaces {
            let displayID =
                state.workspaces.display(of: space.id)
            let display =
                displays.first { $0.id == displayID }
                ?? fallback
            let axVisible = GeometryUtils.flip(
                display.visibleFrame,
                primaryHeight: primaryHeight
            )
            for windowID in space.windows {
                guard
                    let window = state.windows[windowID],
                    !window.isFloating,
                    window.frame.size != .zero
                else { continue }
                let idx = displayIdx[display.id, default: 0]
                displayIdx[display.id] = idx + 1
                result[windowID] = staggeredFrame(
                    size: window.frame.size,
                    in: axVisible,
                    index: idx
                )
            }
        }
        return result
    }
}

extension KiwiCore {
    /// Moves each managed tiled window onto its owning monitor,
    /// staggered within the display's visible area, so windows
    /// are not stranded in tiled frames after KiwiDesk exits.
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
            primaryHeight: primaryH
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
