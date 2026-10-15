import AppKit

/// One app with a window on screen, as a picker's "On screen now"
/// section lists it (#2103 ruling 26, #2297).
public struct OnScreenApp: Equatable, Sendable {
    /// What a rule stores: the lowercased bundle id, or the process
    /// name for an app without one (SketchyBar).
    public let key: String
    /// The name a row shows.
    public let name: String
    /// The bundle id, nil for a process without one.
    public let bundleID: String?

    public init(key: String, name: String, bundleID: String?) {
        self.key = key
        self.name = name
        self.bundleID = bundleID
    }
}

extension KiwiCore {
    /// The apps with a window on screen now, front-most first, one
    /// per app: a normal window, or one beneath the normal layer
    /// above the desktop icons — a status bar such as SketchyBar.
    /// KiwiDesk itself is left out. Read when a picker opens, from
    /// the one front-to-back read; never on a layout pass.
    public func appsOnScreen() -> [OnScreenApp] {
        var seen: Set<String> = []
        var apps: [OnScreenApp] = []
        let own = getpid()
        for window in frontWindowsForPickers()
        where window.pid != own && window.layer <= 0
            && window.layer > Self.desktopIconLayer
        {
            let bundle = pickerBundle(of: window.pid)
            let name =
                state.windows.all
                .first { $0.pid == window.pid }?.appName
                ?? window.owner
            let app = OnScreenApp(
                key: VisionApp(bundleID: bundle, name: window.owner).key,
                name: name.isEmpty ? window.owner : name,
                bundleID: bundle
            )
            guard !app.key.isEmpty, seen.insert(app.key).inserted
            else { continue }
            apps.append(app)
        }
        return apps
    }

    /// The pickers' read of the screen, through the mask's own seam,
    /// so a test core's pin answers it too.
    private func frontWindowsForPickers() -> [FloatDetection.ListedWindow] {
        vision.listWindows()
    }

    private func pickerBundle(of pid: pid_t) -> String? {
        let identity = eventLoop.processIdentity
        return identity.observed[pid]?.ref.bundleID
            ?? identity.unlisted[pid]
            ?? identity.appAt(pid)?.ref.bundleID
    }
}
