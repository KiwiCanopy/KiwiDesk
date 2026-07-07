import AppKit
import CoreGraphics

/// Pure gather-target computation for KiwiDesk shutdown.
///
/// When KiwiDesk stops (quit, disable, restart), managed tiled
/// windows are centered on their owning display so they are not
/// left stranded in tiled frames after the WM exits.
///
/// **Floating-size decision**: KiwiDesk does not yet track a
/// "last-floating size" (no `lastFloatingSize` in state; see
/// issue #70). Gather keeps the window's current frame size —
/// the tiled size the AX echoes last reported — and centers it
/// within the display's visible area. This is a safe,
/// always-visible default. A future pass may record pre-tile
/// sizes for a richer restore.
public enum WindowGather {
    /// Returns a gather-target frame: `size` centered in
    /// `axFrame`, with each edge clamped inside `axFrame`.
    ///
    /// `axFrame` must be in AX (top-left-origin) coordinates;
    /// the returned rect is also in AX coordinates.
    public static func centeredFrame(
        size: CGSize,
        in axFrame: CGRect
    ) -> CGRect {
        let x = axFrame.midX - size.width / 2
        let y = axFrame.midY - size.height / 2
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

    /// Returns a gather target for every tracked, tiled window.
    ///
    /// `primaryHeight` is `NSScreen.screens.first?.frame.height`
    /// (Cocoa coordinates), used to flip `Display.visibleFrame`
    /// into AX (top-left) coordinates. Windows whose space has
    /// no display assignment fall back to the first display.
    /// Floating windows and windows with a zero-size frame are
    /// excluded.
    public static func targets(
        state: StateCoordinator,
        primaryHeight: CGFloat
    ) -> [WindowID: CGRect] {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return [:] }
        let fallback = displays[0]
        var result: [WindowID: CGRect] = [:]
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
                result[windowID] = centeredFrame(
                    size: window.frame.size,
                    in: axVisible
                )
            }
        }
        return result
    }
}

extension KiwiCore {
    /// Moves each managed tiled window onto its owning monitor,
    /// centered within the display's visible area, so windows
    /// are not stranded in tiled frames after KiwiDesk exits.
    ///
    /// Applies frames synchronously (direct AX IPC, 1–20 ms
    /// per window) inside a SkyLight display-suppression
    /// bracket so all moves composite as one visual update.
    ///
    /// Called at the top of `stop()` while the event loop and
    /// AX subsystem are still live.
    func gatherWindows() {
        guard eventLoop.isRunning else { return }
        let primaryH = GeometryUtils.primaryHeight
        let frames = WindowGather.targets(
            state: state,
            primaryHeight: primaryH
        )
        guard !frames.isEmpty else { return }
        SkyLight.suppressDisplay()
        for (id, frame) in frames {
            guard
                let element = eventLoop.element(for: id)
            else { continue }
            WindowControl.setFrame(frame, of: element)
        }
        SkyLight.resumeDisplay()
    }
}
