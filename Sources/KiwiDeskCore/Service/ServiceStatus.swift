import Foundation

/// The `kiwidesk service` agent's launchd state as *structure*, not
/// the English `ServiceManager.Outcome.message` (#576).
/// `AutoStartManager` folds this with the login-item state, so it
/// must read a machine value rather than re-parse a sentence meant
/// for the CLI (Core returns structure, #96).
///
/// `isLoaded` is the job registered with launchd — and because the
/// plist sets `RunAtLoad`, a loaded job auto-starts at login. `pid`
/// is present only while launchd is running the process, so a
/// loaded job with no pid is the quit-but-registered idle case
/// (#341).
public struct ServiceStatus: Equatable, Sendable {
    public let isLoaded: Bool
    public let pid: Int32?

    public init(isLoaded: Bool, pid: Int32?) {
        self.isLoaded = isLoaded
        self.pid = pid
    }

    /// launchd is actively running the process, not merely holding
    /// the job registered.
    public var isRunning: Bool { pid != nil }
}
