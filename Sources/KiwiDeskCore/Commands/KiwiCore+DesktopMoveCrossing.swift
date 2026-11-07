import ApplicationServices
import Foundation

typealias AwayFrameWrite =
    @MainActor (
        WindowID, CGRect, AXUIElement, pid_t,
        @escaping @MainActor (Bool) -> Void
    ) -> Void

/// A Desktop move across screens on shared Desktops (#3048). macOS
/// keeps a window's frame when it changes Desktop, so the move writes
/// the frame onto the named Space's screen through the element kept
/// since the window left. The arrival is then ordinary, and the #1010
/// net stands down by its own predicate.
extension KiwiCore {
    /// How long a move waits for its frame before going ahead: over
    /// the 108 ms worst write measured (macOS 27.2, TextEdit, VS Code,
    /// Firefox), so only a stalled app makes the old screen show.
    static let crossingWriteDeadline: TimeInterval = 0.15
    /// When the frame is read back: a read straight after the write
    /// returned the old frame on nearly every write (#3048).
    static let crossingCheckDelay: TimeInterval = 0.25

    /// Whether moving `window` to a Space on `landing` needs its frame
    /// written. Shared Desktops only, where the target names no screen,
    /// and not for a tracked window onto a shown Desktop, which the
    /// layout carries from its filing.
    func crossesScreens(
        _ window: WindowID,
        to landing: DisplayID,
        _ target: DesktopTarget
    ) -> Bool {
        display(forUUID: target.displayIdentifier) == nil
            && state.workspaces.allDisplays.count > 1
            && (!target.isCurrent || state.awayWindows[window] != nil)
            && screenHolding(window) != landing
    }

    /// Whether a crossing can be written: an element is held, and an
    /// away window is up, since writing to a minimized or hidden one
    /// is unmeasured.
    func canWriteCrossing(_ window: WindowID) -> Bool {
        if state.windows[window] != nil {
            return eventLoop.element(for: window) != nil
        }
        guard state.awayWindows[window]?.isUp == true,
            crossingBaseOfAway(window) != nil
        else { return false }
        return eventLoop.awayElements.element(
            of: window,
            away: Set(state.awayWindows.keys)
        ) != nil
    }

    /// The frame a tracked window carries across, or nil where the
    /// move crosses no screen. A parked float's is its capture, never
    /// the stash corner.
    func crossingBase(
        of window: WindowID,
        to space: SpaceID,
        _ target: DesktopTarget
    ) -> CGRect? {
        guard let landing = state.workspaces.display(of: space),
            crossesScreens(window, to: landing, target)
        else { return nil }
        return tiler.stashOriginal(window) ?? state.windows[window]?.frame
    }

    /// The frame an away window carries across: as `crossingBase`, or
    /// the WindowServer's, since it has no state frame.
    func crossingBaseOfAway(_ window: WindowID) -> CGRect? {
        tiler.stashOriginal(window) ?? windowServer.readWindowBounds(window)
    }

    /// Writes `window`'s frame onto `space`'s screen. `landed` runs
    /// once: with true at the write, or at the deadline for an app
    /// that stalls; with false where nothing can be written.
    func writeCrossingFrame(
        _ window: WindowID,
        from base: CGRect,
        to space: SpaceID,
        landed: @escaping @MainActor (Bool) -> Void
    ) {
        guard let frame = crossingFrame(from: base, to: space) else {
            landed(false)
            return
        }
        tiler.animation.cancel(window: window)
        tiler.forgetStash(window)
        var pending: (@MainActor (Bool) -> Void)? = landed
        let land: @MainActor (Bool) -> Void = { wrote in
            pending?(wrote)
            pending = nil
        }
        sendCrossingFrame(window, frame, resent: false, land: land)
        tiler.applier.scheduleResend(Self.crossingWriteDeadline) {
            land(true)
        }
    }

    private func sendCrossingFrame(
        _ window: WindowID,
        _ frame: CGRect,
        resent: Bool,
        land: @escaping @MainActor (Bool) -> Void
    ) {
        guard
            let element = eventLoop.awayElements.element(
                of: window,
                away: Set(state.awayWindows.keys)
            ),
            let pid = FrameApplier.pid(of: element)
        else {
            onLog("move_to_desktop: w\(window.raw) has no element to write")
            land(false)
            return
        }
        let write: AwayFrameWrite =
            awayFrameWrite ?? tiler.applier.writeAway
        write(window, frame, element, pid) { [weak self] wrote in
            guard let self else { return }
            land(wrote)
            guard wrote else {
                self.onLog(
                    "move_to_desktop: w\(window.raw)'s element names "
                        + "another window now"
                )
                return
            }
            self.tiler.applier.scheduleResend(Self.crossingCheckDelay) {
                [weak self] in
                self?.checkCrossingFrame(window, frame, resent: resent)
            }
        }
    }

    /// One read-back of a write, through the WindowServer's bounds and
    /// never `screenHolding`, whose fallback would pass a failed write.
    /// One resend, then a log line and no rollback. An arrived window's
    /// frame is its layout's by then, so it stands down.
    private func checkCrossingFrame(
        _ window: WindowID,
        _ frame: CGRect,
        resent: Bool
    ) {
        guard state.awayWindows[window] != nil,
            let bounds = windowServer.readWindowBounds(window),
            abs(bounds.minX - frame.minX) > 2
                || abs(bounds.minY - frame.minY) > 2
        else { return }
        guard !resent else {
            onLog(
                "move_to_desktop: w\(window.raw) stayed at \(bounds), "
                    + "not \(frame)"
            )
            return
        }
        sendCrossingFrame(window, frame, resent: true) { _ in }
    }
}
