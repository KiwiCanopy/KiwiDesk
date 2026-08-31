import Foundation

/// Structured launchd service status for kiwidesk service agent (#96, #576).
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
