import AppKit

/// KiwiHub's app strip (#3135): the apps the Windows side lists,
/// most recently used first, read with the rows when the panel
/// opens. An app's recency is its own activation or its windows'
/// latest focus, on one tick (`appRecencyRank`).
extension KiwiCore {
    /// Every app a row lists, then each app activated since
    /// KiwiDesk started that lists none — a regular app still
    /// running, not KiwiDesk, not the one in front — ordered by
    /// recency; ties keep the rows' order.
    func jumpApps(for entries: [JumpEntry]) -> [JumpApp] {
        var apps = JumpApp.listed(in: entries)
        let seen = Set(apps.map(\.pid))
        let stamped = state.appRecency.keys.filter { !seen.contains($0) }
        if !stamped.isEmpty {
            apps += emptyJumpApps(Set(stamped))
        }
        return apps.enumerated().sorted { lhs, rhs in
            let left = state.appRecencyRank(of: lhs.element.pid)
            let right = state.appRecencyRank(of: rhs.element.pid)
            return left != right ? left > right : lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// The stamped apps with no row: their pick reopens them, so
    /// each carries its bundle id; one without is left out.
    private func emptyJumpApps(_ pids: Set<pid_t>) -> [JumpApp] {
        eventLoop.liveApps(owners: []).filter { app in
            pids.contains(app.pid) && app.ref.bundleID != nil
                && !EventLoop.isOwnProcess(app.pid)
                && app.activationPolicy == .regular
                && !frontmostOwns(pid: app.pid)
        }.map { app in
            JumpApp(
                pid: app.pid,
                name: app.ref.name,
                bundleID: app.ref.bundleID
            )
        }
    }

    /// Reopens an app the strip lists with no window, as Open or
    /// Focus does for an app with nothing up (#1840): its launch
    /// follow included.
    public func reopenJumpApp(bundleID: String) {
        withUserMotion {
            _ = launch([.string(bundleID)], newInstance: false)
        }
    }
}
