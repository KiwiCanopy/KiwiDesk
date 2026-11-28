import AppKit

/// KiwiHub's Applications section (#3704): an installed app with no
/// listed window opens from its row. Core names the running apps for
/// the snapshot and answers the press; the GUI ranks the rows.
extension KiwiCore {
    /// The running regular apps by bundle id, in LaunchServices'
    /// order, each listed where a pid in `listed` is one of its
    /// processes or KiwiDesk ignores the app, whose windows have no
    /// row by rule, so the section never offers to reopen one
    /// (#3704).
    /// `live` is the snapshot's one read of the running apps, whose
    /// own policy filters them: no LaunchServices round trip per
    /// process on the hotkey path (#1936).
    func jumpRunningApps(
        _ live: [RunningApp],
        listed: Set<pid_t>
    ) -> [JumpRunningApp] {
        var order: [String] = []
        var apps: [String: JumpRunningApp] = [:]
        for app in live where app.activationPolicy == .regular {
            guard let id = app.ref.bundleID?.lowercased(),
                !EventLoop.isOwnProcess(app.pid)
            else { continue }
            if apps[id] == nil { order.append(id) }
            apps[id] = JumpRunningApp(
                bundleID: id,
                name: apps[id]?.name ?? app.ref.name,
                listed: apps[id]?.listed == true || listed.contains(app.pid)
                    || eventLoop.shouldIgnoreApp(app.ref)
            )
        }
        return order.compactMap { apps[$0] }
    }

    /// Why ↩ on `bundleID`'s app row would open nothing, nil where it
    /// opens: asked at the press (#2885), so an app removed since the
    /// panel opened refuses in the panel.
    public func openAppRefusal(_ bundleID: String) -> JumpOpenBlock? {
        openOrFocus.resolves(bundleID.lowercased()) ? nil : .notFound
    }

    /// Opens `bundleID` from its app row: a launch, or for a running
    /// app with no window a reopen, which has it open one as a Dock
    /// click does (#1840). Its window lands where the app's new
    /// windows land, its App Rule's Space followed (#1599). False
    /// where LaunchServices cannot resolve the id.
    @discardableResult
    public func openApp(_ bundleID: String) -> Bool {
        let id = bundleID.lowercased()
        return withUserMotion {
            guard openOrFocus.openApp(id, .reopen) else {
                onLog("kiwihub: app not found: \(id)")
                return false
            }
            oweLaunchFollow(id)
            return true
        }
    }
}

/// Why an Applications row opens nothing (#3704). Core names it; the
/// GUI words it.
public enum JumpOpenBlock: Sendable, Equatable {
    /// LaunchServices no longer finds the app.
    case notFound
}
