import ApplicationServices

/// Shadow windows (#1785): an empty, button-less standard window
/// beside a real window of its process. It is never
/// tracked, and a focus report naming it names its host — Orion
/// reports its "Orion Preview" twin as the focused window, and a
/// twin tracked as a tile traded focus with its host on every
/// click. `WindowTraits.shadowHost` is the rule.
struct ShadowWindows {
    var traits: (AXUIElement) -> WindowTraits? =
        AXHelper.windowTraits
    var hasTitlebarButton: (AXUIElement) -> Bool =
        AXHelper.hasTitlebarButton
    /// Per process: shadow id → the host it mirrors.
    var hosts: [pid_t: [WindowID: WindowID]] = [:]
    /// Per process: tracked empty button-less windows no host
    /// explained yet — re-asked when a host is tracked, so a twin
    /// that arrived first is dropped however late its host comes.
    var suspects: [pid_t: Set<WindowID>] = [:]
}

extension EventLoop {
    /// `track`'s question, for a standard window: is it a shadow?
    /// A real window pays one button read; only a button-less one
    /// reads its siblings.
    func isShadow(
        _ element: AXUIElement,
        id: WindowID,
        pid: pid_t
    ) -> Bool {
        if shadows.hosts[pid]?[id] != nil { return true }
        guard !shadows.hasTitlebarButton(element),
            let twin = shadows.traits(element)
        else { return false }
        let siblings = axWindows(pid).compactMap(shadows.traits)
        guard
            let host = WindowTraits.shadowHost(
                of: twin,
                among: siblings
            )
        else {
            if twin.childCount == 0 {
                shadows.suspects[pid, default: []].insert(id)
            }
            return false
        }
        shadows.suspects[pid]?.remove(id)
        shadows.hosts[pid, default: [:]][id] = host
        onLog(
            "shadow: w\(id.raw) mirrors w\(host.raw) "
                + "(pid \(pid)) — not tracked"
        )
        return true
    }

    /// The window a focus report means: a shadow's host, else the
    /// window itself.
    func hostOfShadow(_ id: WindowID, pid: pid_t) -> WindowID {
        shadows.hosts[pid]?[id] ?? id
    }

    /// After a window is tracked: a suspect the process's windows
    /// now explain is a shadow, and leaves state.
    func retireShadowSuspects(pid: pid_t) {
        guard let suspects = shadows.suspects[pid], !suspects.isEmpty
        else { return }
        for id in suspects.sorted(by: { $0.raw < $1.raw }) {
            guard let element = elements[pid]?[id] else {
                shadows.suspects[pid]?.remove(id)
                continue
            }
            guard isShadow(element, id: id, pid: pid) else { continue }
            releaseWindowRegistration(id, pid: pid)
            onEvent(.windowDestroyed(id, wasMinimized: false))
        }
    }
}
