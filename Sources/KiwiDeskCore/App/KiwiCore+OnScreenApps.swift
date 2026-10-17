import AppKit

/// One app with a window on screen, as a picker's "On screen now"
/// section lists it (#2103 ruling 26, #2297).
public struct OnScreenApp: Equatable, Sendable {
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
    /// The apps with a normal window on screen now, one per app —
    /// and where `beneathNormal`, one whose window lies beneath the
    /// normal layer above the desktop icons, such as SketchyBar's
    /// bar. KiwiDesk itself is left out; the order is the caller's.
    /// Read when a picker opens, from the one front-to-back read
    /// the mask takes; never on a layout pass.
    public func appsOnScreen(beneathNormal: Bool) -> [OnScreenApp] {
        var seen: Set<String> = []
        var apps: [OnScreenApp] = []
        let own = getpid()
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
            let app = OnScreenApp(
                app: ref,
                name: tracked.isEmpty ? window.owner : tracked
            )
            guard !app.key.isEmpty, seen.insert(app.key).inserted
            else { continue }
            apps.append(app)
        }
        return apps
    }
}
