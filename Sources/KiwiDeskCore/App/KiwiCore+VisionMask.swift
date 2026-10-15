import AppKit

/// KiwiVision's mask (#2103 ruling 21): which windows sit below
/// the plates, front to back, and how the mask follows them. The
/// plate draws over every window but the target unless a v2
/// switch asks for a shape (`VisionMask`).
extension KiwiCore {
    /// Whether the plates draw a mask rather than the whole screen.
    var visionMasks: Bool {
        vision.isOn
            && (appWide.visionClearWallpaper || appWide.visionClearApp)
    }

    /// The windows below the plates, front to back, in AppKit
    /// global frames: the WindowServer's order from the cached
    /// list, a shown Space's member at the frame the engine last
    /// sent — so a pass's mask lands with its windows rather than
    /// their echoes — and every other app's normal window at its
    /// listed bounds. A member the list has not seen yet goes in
    /// front: it arrived since the read. The float tier sits below
    /// the plate (#2287), so a float takes a verdict like any
    /// window. With "the current app's other windows" on, a window
    /// of the target's app — one process, or a sibling of it
    /// (`EventLoop.names(_:appOf:)`, #1785) — is clear: a hole for
    /// its visible part.
    /// KiwiDesk's own untiled windows — a dialog, the update and
    /// What's new windows — are chrome to the read and stay clear.
    /// Corner radii are read only on a list read, off the switch
    /// path: a member takes the ring's cached reading there.
    func visionMaskWindows(
        target: CGWindowID?,
        refreshingList: Bool
    ) -> [VisionMask.Window] {
        var members: [WindowID] = []
        for placement in tiler.visiblePlacements(state: state) {
            for id in state.effectiveMembers(of: placement.space)
            where id.raw != target {
                guard state.windows[id]?.isFullscreen == false
                else { continue }
                members.append(id)
            }
        }
        let shown = Set(members)
        let listed = vision.listedWindows(
            refresh: refreshingList,
            tracks: { self.state.windows[WindowID($0)] != nil },
            radius: { self.windowRadius(WindowID($0), reading: true) }
        )
        let seen = Set(listed.map { WindowID($0.number) })
        var ordered: [(id: WindowID, frame: CGRect, pid: pid_t)] = []
        func member(_ id: WindowID) {
            guard let frame = memberFrame(id),
                let pid = state.windows[id]?.pid
            else { return }
            ordered.append((id, frame, pid))
        }
        for id in members where !seen.contains(id) { member(id) }
        for entry in listed {
            let id = WindowID(entry.number)
            if shown.contains(id) {
                member(id)
                continue
            }
            guard entry.layer == 0, entry.number != target,
                !vision.trackedAtRead.contains(entry.number),
                state.windows[id] == nil
            else { continue }
            ordered.append((id, entry.frame, entry.pid))
        }
        let clearApp = visionClearAppPid(target: target)
        let height = GeometryUtils.primaryHeight
        return ordered.map { id, frame, pid in
            VisionMask.Window(
                frame: GeometryUtils.flip(frame, primaryHeight: height),
                cornerRadius: vision.listedRadii[id.raw]
                    ?? windowRadius(id, reading: refreshingList),
                clear: clearApp.map { eventLoop.names($0, appOf: pid) }
                    ?? false
            )
        }
    }

    /// The target's process while "the current app's other
    /// windows" is on: a tracked target's, else this one's — the
    /// target is then an own key window. Nil while off.
    private func visionClearAppPid(target: CGWindowID?) -> pid_t? {
        guard appWide.visionClearApp, let target else { return nil }
        return state.windows[WindowID(target)]?.pid ?? getpid()
    }

    /// A window's corner radius: the ring's reading, read from the
    /// WindowServer only where `reading` allows, else its cache or
    /// the system radius.
    private func windowRadius(_ id: WindowID, reading: Bool) -> CGFloat {
        if reading, state.windows[id] != nil {
            return borders.cornerRadius(for: id)
        }
        if reading {
            return borders.readCornerRadius(id.raw)
                ?? GeometryUtils.systemWindowCornerRadius
        }
        return borders.cornerRadii[id]
            ?? GeometryUtils.systemWindowCornerRadius
    }

    /// The other apps' listed windows a mask draws, so the plate's
    /// WindowServer consumer hears them move, hide or close.
    func visionMaskListedIDs() -> Set<WindowID> {
        guard visionMasks, let listed = vision.listed else { return [] }
        return Set(
            listed.lazy
                .filter {
                    $0.layer == 0
                        && !self.vision.trackedAtRead.contains($0.number)
                }
                .map { WindowID($0.number) }
                .filter { self.state.windows[$0] == nil }
        )
    }

    private func memberFrame(_ id: WindowID) -> CGRect? {
        tiler.commandedFrame(of: id) ?? state.windows[id]?.frame
    }

    /// An event's effect on a standing mask: a tracked window that
    /// moved re-masks from state; a window or app that came, went
    /// or changed Desktop owes the list a fresh read. Neither runs
    /// on the event's own turn.
    func noteVisionMaskEvent(_ event: KiwiEvent) {
        guard visionMasks, vision.hasShownPlates else { return }
        switch event {
        case .windowMoved, .windowResized, .windowFloatChanged,
            .windowFullscreenChanged, .windowFocused:
            oweVisionReshape(list: false)
        case .windowCreated, .windowDestroyed, .windowHidden,
            .appLaunched, .appTerminated, .desktopChanged,
            .displaysChanged, .windowRekeyed:
            oweVisionReshape(list: true)
        default:
            break
        }
    }

    /// A listed window's own WindowServer event: its bounds moved
    /// (CG coordinates) or, with nil, it hid or closed.
    func visionListedWindowChanged(_ id: WindowID, frame: CGRect?) {
        // A tracked window's frame is state's; its slot in the list
        // stays where the read put it.
        guard visionMasks, state.windows[id] == nil,
            !vision.trackedAtRead.contains(id.raw),
            vision.noteListedWindow(id.raw, frame: frame)
        else { return }
        oweVisionReshape(list: false)
    }

    /// Re-masks the shown plates soon, re-reading the list first
    /// where `list` asks; coalesced, so a drag re-masks per frame
    /// at most and a burst of arrivals reads the list once.
    func oweVisionReshape(list: Bool) {
        if list { vision.listOwed = true }
        deferred.schedule(
            .visionMask,
            after: .milliseconds(list ? 120 : 16),
            maxWait: .milliseconds(250)
        ) { [weak self] in self?.reshapeVision() }
    }

    /// Re-masks every shown plate from the live windows, ordering
    /// nothing; reads the list only where an event owed it.
    func reshapeVision() {
        guard visionMasks else { return }
        let refresh = vision.listOwed
        vision.listOwed = false
        vision.reshapeShown(visionRequest(refreshingList: refresh))
        if refresh { requestVisionWindows() }
    }
}
