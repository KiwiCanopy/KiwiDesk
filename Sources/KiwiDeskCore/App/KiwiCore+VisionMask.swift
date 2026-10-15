import AppKit

/// KiwiVision's mask (#2103 ruling 21): which windows sit below
/// the plates, front to back, and how the mask follows them. The
/// plate draws over every window but the target unless a v2
/// switch asks for a shape (`VisionMask`).
extension KiwiCore {
    /// Whether the plates draw a mask rather than the whole screen.
    var visionMasks: Bool {
        vision.isOn && appWide.visionClearWallpaper
    }

    /// The windows below the plates, front to back, in AppKit
    /// global frames: the WindowServer's order from the cached
    /// list, a shown Space's member at the frame the engine last
    /// sent — so a pass's mask lands with its windows rather than
    /// their echoes — and every other app's normal window at its
    /// listed bounds. A member the list has not seen yet goes in
    /// front: it arrived since the read.
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
        let listed = vision.listedWindows(refresh: refreshingList) {
            self.state.windows[WindowID($0)] != nil
        }
        let seen = Set(listed.map { WindowID($0.number) })
        var ordered: [(id: WindowID, frame: CGRect)] = []
        for id in members where !seen.contains(id) {
            if let frame = memberFrame(id) { ordered.append((id, frame)) }
        }
        for entry in listed {
            let id = WindowID(entry.number)
            if shown.contains(id) {
                if let frame = memberFrame(id) {
                    ordered.append((id, frame))
                }
                continue
            }
            guard entry.layer == 0, entry.number != target,
                !vision.trackedAtRead.contains(entry.number),
                state.windows[id] == nil
            else { continue }
            ordered.append((id, entry.frame))
        }
        let height = GeometryUtils.primaryHeight
        return ordered.map { id, frame in
            VisionMask.Window(
                frame: GeometryUtils.flip(frame, primaryHeight: height),
                cornerRadius: borders.cornerRadius(for: id),
                clear: false
            )
        }
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
        guard visionMasks,
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
