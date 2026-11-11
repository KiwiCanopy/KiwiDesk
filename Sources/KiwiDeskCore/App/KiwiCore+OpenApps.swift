import AppKit

/// One app with a window open, as a picker's "Open apps" section
/// lists it (#2103 ruling 26, #2297).
public struct OpenApp: Equatable, Sendable {
    /// The app: its bundle id, nil for a process without one, and
    /// its process name.
    public let app: AppRef
    /// The name a row shows.
    public let name: String

    public init(app: AppRef, name: String) {
        self.app = app
        self.name = name
    }

    /// What a list stores for it (`AppRef.listKey`).
    public var key: String { app.listKey }
    /// The bundle id, nil for a process without one.
    public var bundleID: String? { app.bundleID }
}

extension KiwiCore {
    /// The apps with a window open, one per app: every app with a
    /// tracked window on any Space — the pocket window's in both
    /// phases, its app being open either way (#2446) — every app
    /// with a window on an away Desktop (#1146), and every app
    /// with a normal window on screen now, and where
    /// `beneathNormal`, one whose window lies beneath the normal
    /// layer above the desktop icons, such as SketchyBar's bar,
    /// which no Space tracks. KiwiDesk itself is left out; the
    /// order is the caller's. Read when a picker opens, from the
    /// one front-to-back read the mask takes; never on a layout
    /// pass.
    public func openApps(beneathNormal: Bool) -> [OpenApp] {
        var seen: Set<String> = []
        var apps: [OpenApp] = []
        let own = getpid()
        func add(_ app: OpenApp) {
            guard !app.key.isEmpty, seen.insert(app.key).inserted
            else { return }
            apps.append(app)
        }
        for window in state.windows.all where window.pid != own {
            let name =
                window.appName.isEmpty
                ? window.appBundleID ?? "" : window.appName
            add(
                OpenApp(
                    app: AppRef(bundleID: window.appBundleID, name: name),
                    name: name
                )
            )
        }
        for window in state.awayWindows.values where window.pid != own {
            add(
                OpenApp(
                    app: AppRef(
                        bundleID: window.appBundleID,
                        name: window.appName
                    ),
                    name: window.appName
                )
            )
        }
        for window in vision.listWindows() where window.pid != own {
            guard
                window.layer == 0
                    || (beneathNormal
                        && Self.isBeneathNormal(layer: window.layer))
            else { continue }
            let ref = AppRef(
                bundleID: eventLoop.bundle(of: window.pid, lookingUp: true),
                name: window.owner
            )
            let tracked =
                state.windows.all
                .first { $0.pid == window.pid }?.appName ?? ""
            add(
                OpenApp(
                    app: ref,
                    name: tracked.isEmpty ? window.owner : tracked
                )
            )
        }
        return apps
    }
}
