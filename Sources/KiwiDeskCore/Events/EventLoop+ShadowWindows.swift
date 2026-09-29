import ApplicationServices

/// Shadow windows (#1785): an empty, button-less standard window
/// beside a real window of its process — Orion's "Orion Preview".
/// Never tracked; a focus report naming it names its host.
/// `WindowTraits.shadowHost` is the rule.
struct ShadowWindows {
    var hasTitlebarButton: (AXUIElement) -> Bool =
        AXHelper.hasTitlebarButton
    var childCount: (AXUIElement) -> Int = AXHelper.childCount
    var traits: (AXUIElement) -> WindowTraits? =
        AXHelper.windowTraits
    /// An app's AX-focused window id, before any shadow mapping.
    var focusedWindow: (pid_t) -> WindowID? = { pid in
        AXHelper.focusedWindow(pid: pid).flatMap {
            AXHelper.windowID(of: $0)
        }
    }
    /// Per process: shadow id → the host it mirrors.
    private(set) var hosts: [pid_t: [WindowID: WindowID]] = [:]
    /// Per process: windows tracked empty and button-less with no
    /// host — re-asked at each reconcile, since a host can list
    /// after its twin's one re-track (device, 2026-09-30).
    private(set) var suspects: [pid_t: Set<WindowID>] = [:]
    /// Per process: when a lone candidate was first seen. It
    /// waits `hostWait` for a host before it may tile, because a
    /// tile KiwiDesk resizes never matches its host again, and a
    /// fresh Orion lists its host over a second late (device,
    /// 2026-09-30).
    private(set) var firstSeen: [pid_t: [WindowID: ContinuousClock.Instant]] =
        [:]
    static let hostWait: Duration = .seconds(3)

    /// Whether a lone candidate still waits for its host.
    mutating func waits(
        _ id: WindowID,
        pid: pid_t,
        now: ContinuousClock.Instant
    ) -> Bool {
        let seen = firstSeen[pid]?[id] ?? now
        firstSeen[pid, default: [:]][id] = seen
        return seen.duration(to: now) < Self.hostWait
    }

    mutating func suspect(_ id: WindowID, pid: pid_t) {
        suspects[pid, default: []].insert(id)
    }

    mutating func clear(_ id: WindowID, pid: pid_t) {
        suspects[pid]?.remove(id)
        firstSeen[pid]?[id] = nil
    }

    mutating func record(_ id: WindowID, host: WindowID, pid: pid_t) {
        hosts[pid, default: [:]][id] = host
    }

    /// Keeps only the entries whose shadow is still listed.
    mutating func prune(pid: pid_t, listed: Set<WindowID>) {
        hosts[pid] = hosts[pid]?.filter { listed.contains($0.key) }
    }

    mutating func forget(pid: pid_t) {
        hosts[pid] = nil
        suspects[pid] = nil
        firstSeen[pid] = nil
    }

    mutating func forgetAll() {
        hosts = [:]
        suspects = [:]
        firstSeen = [:]
    }
}

/// What `track` does with a standard window (#1785).
enum ShadowVerdict: Equatable {
    case window
    case shadow
    /// Empty and button-less with no host yet: re-asked on the
    /// re-track until `ShadowWindows.hostWait` passes, since a
    /// twin can list before its host does.
    case deferred
}

extension EventLoop {
    /// `track`'s question for a standard window. A window with a
    /// button pays one read, one with content two; only an empty,
    /// button-less one reads its siblings. A cached verdict is
    /// re-asked on those same two reads, so a window that gains
    /// content or a button becomes a window.
    func shadowVerdict(
        _ element: AXUIElement,
        id: WindowID,
        pid: pid_t
    ) -> ShadowVerdict {
        guard !shadows.hasTitlebarButton(element),
            shadows.childCount(element) == 0
        else {
            shadows.clear(id, pid: pid)
            return .window
        }
        if shadows.hosts[pid]?[id] != nil { return .shadow }
        let siblings = axWindows(pid).compactMap(shadows.traits)
        shadows.prune(pid: pid, listed: Set(siblings.map(\.id)))
        guard let twin = siblings.first(where: { $0.id == id }),
            let host = WindowTraits.shadowHost(
                of: twin,
                among: siblings
            )
        else {
            if shadows.waits(id, pid: pid, now: monotonicNow()) {
                queueRetrack(pid: pid)
                return .deferred
            }
            shadows.suspect(id, pid: pid)
            return .window
        }
        shadows.clear(id, pid: pid)
        shadows.record(id, host: host, pid: pid)
        onLog(
            "shadow: w\(id.raw) mirrors w\(host.raw) "
                + "(pid \(pid)) — not tracked"
        )
        return .shadow
    }

    /// The window a focus report means: a shadow's host, else the
    /// window itself.
    func hostOfShadow(_ id: WindowID, pid: pid_t) -> WindowID {
        shadows.hosts[pid]?[id] ?? id
    }

    /// The app's AX-focused window as a tracked id would name it —
    /// the one read every activation-time focus takes, so no
    /// reader forgets a shadow's host.
    func focusedWindowID(pid: pid_t) -> WindowID? {
        shadows.focusedWindow(pid).map { hostOfShadow($0, pid: pid) }
    }

    /// At a reconcile's end: a tracked suspect its process's
    /// windows now explain leaves state as a HIDE, never a close —
    /// no close-return raise, no closed-return mark, for a window
    /// nobody closed.
    func retireShadowSuspects(pid: pid_t) {
        guard let ids = shadows.suspects[pid], !ids.isEmpty else {
            return
        }
        for id in ids.sorted(by: { $0.raw < $1.raw }) {
            guard let element = elements[pid]?[id] else {
                shadows.clear(id, pid: pid)
                continue
            }
            guard shadowVerdict(element, id: id, pid: pid) == .shadow
            else { continue }
            releaseWindowRegistration(id, pid: pid)
            onEvent(.windowHidden(id))
        }
    }
}
