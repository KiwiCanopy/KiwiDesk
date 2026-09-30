import ApplicationServices

/// Shadow windows (#1785): a window with no title-bar button and
/// no AX child beside a buttoned window of its process — Orion's
/// "Orion Preview". Never a tile, whatever its subrole reads; a
/// focus report naming one names a real window of its process.
/// `WindowTraits.shadowHost` is the rule.
struct ShadowWindows {
    /// One window's reading, in one round trip; the id is handed
    /// in where the caller already holds it.
    var traits: (AXUIElement, WindowID?) -> WindowTraits? =
        AXHelper.windowTraits
    /// An app's AX-focused window id, before any shadow mapping.
    var focusedWindow: (pid_t) -> WindowID? = { pid in
        AXHelper.focusedWindow(pid: pid).flatMap {
            AXHelper.windowID(of: $0)
        }
    }
    /// Per process: shadow id → the host it was judged against.
    private(set) var hosts: [pid_t: [WindowID: WindowID]] = [:]
    /// Per process: when a candidate without a verdict was first
    /// seen. It waits `hostWait` before it may track, because a
    /// fresh Orion lists its host over a second after the twin
    /// (device, 2026-09-30).
    private(set) var firstSeen: [pid_t: [WindowID: ContinuousClock.Instant]] =
        [:]
    /// The wait is a launch's: only a process that shows nothing
    /// tracked yet pays it, so a decoration-less window opened
    /// beside another of its app tiles at once.
    static let hostWait: Duration = .seconds(3)

    /// Whether a candidate still waits, and whether this ask
    /// opened the wait.
    mutating func waits(
        _ id: WindowID,
        pid: pid_t,
        now: ContinuousClock.Instant
    ) -> (waiting: Bool, opened: Bool) {
        let known = firstSeen[pid]?[id]
        let seen = known ?? now
        firstSeen[pid, default: [:]][id] = seen
        return (seen.duration(to: now) < Self.hostWait, known == nil)
    }

    /// Whether the rule holds a verdict or a wait on the window.
    func holds(_ id: WindowID, pid: pid_t) -> Bool {
        hosts[pid]?[id] != nil || firstSeen[pid]?[id] != nil
    }

    /// A verdict ends the wait: only readings with none in
    /// between count toward `hostWait`.
    mutating func endWait(_ id: WindowID, pid: pid_t) {
        firstSeen[pid]?[id] = nil
    }

    /// A window with content is nobody's shadow.
    mutating func clear(_ id: WindowID, pid: pid_t) {
        hosts[pid]?[id] = nil
        firstSeen[pid]?[id] = nil
    }

    mutating func record(_ id: WindowID, host: WindowID, pid: pid_t) {
        hosts[pid, default: [:]][id] = host
        firstSeen[pid]?[id] = nil
    }

    /// A record dies with its host: kept only while the host is
    /// still listed, so a window judged a shadow beside a sibling
    /// that then closed is asked again — at the reconcile that
    /// lost the host, ahead of its sweep.
    mutating func prune(pid: pid_t, listed: Set<WindowID>) {
        hosts[pid] = hosts[pid]?.filter { listed.contains($0.value) }
    }

    mutating func forget(pid: pid_t) {
        hosts[pid] = nil
        firstSeen[pid] = nil
    }

    mutating func forgetAll() {
        hosts = [:]
        firstSeen = [:]
    }
}

/// What `track` does with a window (#1785).
enum ShadowVerdict: Equatable {
    case window
    case shadow
    /// No verdict yet — a shell with no host, or a read that did
    /// not answer: re-asked on the re-track until
    /// `ShadowWindows.hostWait` passes.
    case deferred
}

extension EventLoop {
    /// The process's listed windows as the rule reads them.
    private func siblingTraits(_ pid: pid_t) -> [WindowTraits] {
        axWindows(pid).compactMap { shadows.traits($0, nil) }
    }

    /// `track`'s question for every window, one round trip for
    /// any but a shell, which reads its siblings. Asked again each
    /// time the window is offered: one that gains content or a
    /// button becomes a window.
    func shadowVerdict(
        _ element: AXUIElement,
        id: WindowID,
        pid: pid_t
    ) -> ShadowVerdict {
        guard let twin = shadows.traits(element, id) else {
            return .window
        }
        switch twin.reading {
        case .furnished:
            shadows.clear(id, pid: pid)
            return .window
        case .unread:
            // A read that fails as the window leaves the list
            // takes no verdict back (device, 2026-09-30).
            if shadows.hosts[pid]?[id] != nil { return .shadow }
            return waitOrTrack(id, pid: pid, reading: "unread")
        case .shell:
            if shadows.hosts[pid]?[id] != nil { return .shadow }
            let siblings = siblingTraits(pid)
            guard
                let host = WindowTraits.shadowHost(
                    of: twin,
                    among: siblings
                )
            else {
                // A process already showing a tracked window is
                // past its launch: nothing of its lists late.
                guard elements[pid]?.isEmpty ?? true else {
                    shadows.endWait(id, pid: pid)
                    return .window
                }
                return waitOrTrack(id, pid: pid, reading: "alone")
            }
            shadows.record(id, host: host, pid: pid)
            onLog(
                "shadow: w\(id.raw) mirrors w\(host.raw) "
                    + "(pid \(pid)) — not tracked"
            )
            return .shadow
        }
    }

    private func waitOrTrack(
        _ id: WindowID,
        pid: pid_t,
        reading: String
    ) -> ShadowVerdict {
        let wait = shadows.waits(id, pid: pid, now: monotonicNow())
        guard wait.waiting else {
            // Tracked from here: the rule holds nothing on it.
            shadows.endWait(id, pid: pid)
            onLog(
                "shadow: w\(id.raw) (pid \(pid)) still \(reading) "
                    + "— tracked"
            )
            return .window
        }
        if wait.opened {
            onLog(
                "shadow: w\(id.raw) (pid \(pid)) reads \(reading) "
                    + "— waits for a host"
            )
        }
        queueRetrack(pid: pid)
        return .deferred
    }

    /// The window a focus report means. A shadow names the
    /// front-most tracked window of its process, else the host it
    /// was judged against; any other window names itself.
    func hostOfShadow(_ id: WindowID, pid: pid_t) -> WindowID {
        guard let recorded = shadows.hosts[pid]?[id] else { return id }
        let tracked = elements[pid] ?? [:]
        guard tracked.count > 1 else {
            return tracked.keys.first ?? recorded
        }
        let front = processIdentity.frontToBack().first {
            $0.pid == pid && tracked[$0.id] != nil
        }
        return front?.id ?? recorded
    }

    /// The app's AX-focused window as a tracked id would name it —
    /// the one read every activation-time focus takes, so no
    /// reader forgets a shadow's host.
    func focusedWindowID(pid: pid_t) -> WindowID? {
        shadows.focusedWindow(pid).map { hostOfShadow($0, pid: pid) }
    }

    /// At a reconcile's end every tracked window it listed is
    /// re-asked, one round trip each: one tracked while it read
    /// as a window — its host not listed yet, its content gone
    /// since — is handed back as a HIDE, never a close: no
    /// close-return raise and no closed-return mark for a window
    /// nobody closed. False when a queued boot step's budget ran
    /// out first, so the caller defers the app (#803).
    func retireShadows(
        pid: pid_t,
        listed: [(element: AXUIElement, id: WindowID)],
        budget: AppBudget
    ) -> Bool {
        // A shell needs a buttoned sibling: one window is spared
        // the read.
        guard listed.count > 1 else { return true }
        var siblings: [WindowTraits] = []
        for pair in listed where elements[pid]?[pair.id] != nil {
            // The budget's checkpoint between blocking reads (#803).
            guard !budget.isSpent else { return false }
            if let traits = shadows.traits(pair.element, pair.id) {
                siblings.append(traits)
            }
        }
        for twin in siblings where twin.reading == .shell {
            let id = twin.id
            guard
                let host = WindowTraits.shadowHost(
                    of: twin,
                    among: siblings
                )
            else { continue }
            shadows.record(id, host: host, pid: pid)
            onLog(
                "shadow: w\(id.raw) mirrors w\(host.raw) "
                    + "(pid \(pid)) — was tracked, handed back"
            )
            releaseWindowRegistration(id, pid: pid)
            onEvent(.windowHidden(id))
        }
        return true
    }
}
