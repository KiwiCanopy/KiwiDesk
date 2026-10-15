import AppKit

/// KiwiVision's mask (#2103 ruling 21): which windows sit below
/// the plates, front to back, and how the mask follows them. The
/// plate draws over every window but the target unless a v2
/// switch asks for a shape (`VisionMask`).
extension KiwiCore {
    /// Whether the plates draw a mask rather than the whole screen.
    var visionMasks: Bool {
        visionClearsWallpaper
            || (vision.isOn
                && (appWide.visionClearApp
                    || !appWide.visionNeverDimmed.isEmpty))
    }

    /// Whether the wallpaper stays clear now — the one reading the
    /// request's flag and the mask gate share.
    var visionClearsWallpaper: Bool {
        vision.isOn && appWide.visionClearWallpaper
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
    /// its visible part. A window of a Never dimmed app is clear
    /// too, beneath the normal layer as well — SketchyBar draws its
    /// bar at layer −20, under every window — down to, never
    /// including, the desktop icons' level.
    /// KiwiDesk's own untiled windows — a dialog, the update and
    /// What's new windows — are chrome to the read and stay clear.
    /// Corner radii are read only on a list read, off the switch
    /// path: a member takes the ring's cached reading there.
    func visionMaskWindows(
        target: CGWindowID?,
        targetPid: pid_t?,
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
            radius: { self.windowRadius(WindowID($0), reading: true) },
            bundle: appWide.visionNeverDimmed.isEmpty
                ? nil
                : { self.eventLoop.bundle(of: $0, lookingUp: true) }
        )
        let seen = Set(listed.map { WindowID($0.number) })
        var ordered: [(id: WindowID, frame: CGRect, pid: pid_t)] = []
        var apps: [pid_t: AppRef] = [:]
        func member(_ id: WindowID) {
            guard let frame = memberFrame(id), let window = state.windows[id]
            else { return }
            ordered.append((id, frame, window.pid))
            apps[window.pid] =
                apps[window.pid]
                ?? AppRef(
                    bundleID: window.appBundleID,
                    name: window.appName
                )
        }
        for id in members where !seen.contains(id) { member(id) }
        for entry in listed {
            let id = WindowID(entry.number)
            if shown.contains(id) {
                member(id)
                continue
            }
            guard entry.number != target,
                !vision.trackedAtRead.contains(entry.number),
                state.windows[id] == nil,
                visionMaskReads(entry)
            else { continue }
            ordered.append((id, entry.frame, entry.pid))
            apps[entry.pid] = apps[entry.pid] ?? listedApp(entry)
        }
        let clear = visionClearPids(target: targetPid, among: apps)
        let height = GeometryUtils.primaryHeight
        return ordered.map { id, frame, pid in
            VisionMask.Window(
                frame: GeometryUtils.flip(frame, primaryHeight: height),
                cornerRadius: vision.listedRadii[id.raw]
                    ?? windowRadius(id, reading: refreshingList),
                clear: clear.contains(pid)
            )
        }
    }

    /// The processes whose windows stay clear this pass: with "the
    /// current app's other windows" on, every one of `pids` that
    /// names the target's app — the one identity door, read from
    /// what attach filed and never LaunchServices (#1785, #1936).
    /// Decided once per pass, per process; Never dimmed joins it —
    /// an app named by its bundle id, or by its process name where
    /// it has none (#2103 ruling 26) — and a lens will too.
    func visionClearPids(
        target: pid_t?,
        among apps: [pid_t: AppRef]
    ) -> Set<pid_t> {
        var clear: Set<pid_t> = []
        for (pid, app) in apps {
            if isNeverDimmed(app) {
                clear.insert(pid)
            } else if appWide.visionClearApp, let target, target > 0,
                eventLoop.names(target, appOf: pid, lookingUp: false)
            {
                clear.insert(pid)
            }
        }
        return clear
    }

    /// Whether the mask reads a listed window of another app: a
    /// normal one, or one beneath the normal layer — above the
    /// desktop icons — of a Never dimmed app.
    private func visionMaskReads(
        _ entry: FloatDetection.ListedWindow
    ) -> Bool {
        if entry.layer == 0 { return true }
        return Self.isBeneathNormal(layer: entry.layer)
            && isNeverDimmed(listedApp(entry))
    }

    /// Whether the Never dimmed list names `app`.
    private func isNeverDimmed(_ app: AppRef) -> Bool {
        let list = appWide.visionNeverDimmed
        return !list.isEmpty && list.contains(app.listKey)
    }

    /// The desktop icons' level: a hole there would clear the
    /// whole wallpaper.
    static let desktopIconLayer = Int(
        CGWindowLevelForKey(.desktopIconWindow)
    )

    /// Whether a window layer lies beneath the normal one and above
    /// the desktop icons — where SketchyBar draws its bar.
    static func isBeneathNormal(layer: Int) -> Bool {
        layer < 0 && layer > desktopIconLayer
    }

    private func listedApp(_ entry: FloatDetection.ListedWindow) -> AppRef {
        AppRef(
            bundleID: vision.listedBundles[entry.pid] ?? nil,
            name: entry.owner
        )
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
                    self.visionMaskReads($0)
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
