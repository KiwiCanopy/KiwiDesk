import Foundation

/// Structured launchd service status (#576) — a machine value,
/// never a re-parsed CLI sentence (#96). `isLoaded` is the job
/// registered with launchd (RunAtLoad ⇒ auto-starts at login);
/// `pid` exists only while running, so loaded with no pid is
/// the quit-but-registered idle case (#341).
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
