import AppKit

/// A window manager other than KiwiDesk, known by its bundle id
/// (#1882). The name is the product's own, so it is not localized.
public struct OtherWindowManager: Sendable, Hashable {
    public let bundleID: String
    public let name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// Notices another window manager running beside KiwiDesk (#1882):
/// two managers arranging the same windows read as a KiwiDesk bug.
/// Core states when one starts and when its last process exits; the
/// GUI words the warning and owns its silencing. Warns only —
/// nothing here stops tiling. A manager is announced once while it
/// runs: its exit, or a relaunch of KiwiDesk, lets the next start
/// warn again until the user silences it.
@MainActor
public final class OtherWindowManagerWatch {
    /// The one list of managers KiwiDesk knows. Extend it here.
    public static let known: [OtherWindowManager] = [
        OtherWindowManager(bundleID: "bobko.aerospace", name: "AeroSpace"),
        OtherWindowManager(
            bundleID: "com.amethyst.Amethyst",
            name: "Amethyst"
        ),
        OtherWindowManager(bundleID: "com.barut.OmniWM", name: "OmniWM"),
    ]

    /// Fired when a known manager starts running: at boot for one
    /// already running, at its launch for one starting later.
    public var onDetected: @MainActor (OtherWindowManager) -> Void = {
        _ in
    }

    /// Fired when the last process of an announced manager exits.
    public var onGone: @MainActor (OtherWindowManager) -> Void = { _ in }

    /// Asks one process to quit; a test injects its own.
    var terminate: @MainActor (pid_t) -> Void = { pid in
        NSRunningApplication(processIdentifier: pid)?.terminate()
    }

    /// The running processes of each announced manager.
    private var running: [OtherWindowManager: Set<pid_t>] = [:]

    public init() {}

    /// Asks every running process of `manager` to quit. Its exit
    /// arrives as `onGone`; a refusal leaves it running.
    public func quit(_ manager: OtherWindowManager) {
        for pid in running[manager] ?? [] {
            terminate(pid)
        }
    }

    /// Boot's pass over the apps already running.
    func scanRunning(_ apps: [(pid: pid_t, bundleID: String?)]) {
        for app in apps {
            noteLaunch(pid: app.pid, bundleID: app.bundleID)
        }
    }

    func noteLaunch(pid: pid_t, bundleID: String?) {
        // LaunchServices compares bundle ids case-insensitively,
        // and `AppRef` hands them lower-cased.
        guard let bundleID = bundleID?.lowercased(),
            let manager = Self.known.first(where: {
                $0.bundleID.lowercased() == bundleID
            })
        else { return }
        let isNew = running[manager] == nil
        running[manager, default: []].insert(pid)
        if isNew { onDetected(manager) }
    }

    func noteExit(pid: pid_t) {
        guard
            let manager = running.first(where: {
                $0.value.contains(pid)
            })?.key
        else { return }
        running[manager]?.remove(pid)
        guard running[manager]?.isEmpty == true else { return }
        running[manager] = nil
        onGone(manager)
    }
}
