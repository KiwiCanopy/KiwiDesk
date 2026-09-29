import ApplicationServices

/// Shadow windows (#1785): an empty, button-less standard window
/// stacked exactly on a real window of its process. It is never
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
        else { return false }
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
}
