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
    /// Per process: shadow id → the host it mirrors.
    private(set) var hosts: [pid_t: [WindowID: WindowID]] = [:]

    mutating func record(_ id: WindowID, host: WindowID, pid: pid_t) {
        hosts[pid, default: [:]][id] = host
    }

    /// Keeps only the entries whose shadow is still listed.
    mutating func prune(pid: pid_t, listed: Set<WindowID>) {
        hosts[pid] = hosts[pid]?.filter { listed.contains($0.key) }
    }

    mutating func forget(pid: pid_t) { hosts[pid] = nil }
    mutating func forgetAll() { hosts = [:] }
}

/// What `track` does with a standard window (#1785).
enum ShadowVerdict: Equatable {
    case window
    case shadow
    /// Empty and button-less with no host yet: asked again on the
    /// one-shot re-track before it may become a tile, since a twin
    /// can list before its host does.
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
        else { return .window }
        if shadows.hosts[pid]?[id] != nil { return .shadow }
        let siblings = axWindows(pid).compactMap(shadows.traits)
        shadows.prune(pid: pid, listed: Set(siblings.map(\.id)))
        guard let twin = siblings.first(where: { $0.id == id }),
            let host = WindowTraits.shadowHost(
                of: twin,
                among: siblings
            )
        else {
            return markTransientDrop(pid: pid, id: id)
                ? .deferred : .window
        }
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
        AXHelper.focusedWindow(pid: pid)
            .flatMap { AXHelper.windowID(of: $0) }
            .map { hostOfShadow($0, pid: pid) }
    }
}
