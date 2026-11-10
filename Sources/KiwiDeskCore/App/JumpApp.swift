import Foundation

/// One tile of KiwiHub's app strip (#3135): an app the Windows
/// side lists, by the process that owns its rows. Core names the
/// app; the GUI draws the tile and counts its rows from the
/// snapshot's entries, so a count is never a second reading.
public struct JumpApp: Sendable, Equatable {
    public let pid: pid_t
    public let name: String
    /// Set for an app no row lists, whose pick reopens it (#1840);
    /// nil where its rows say the rest.
    public let bundleID: String?

    public init(pid: pid_t, name: String, bundleID: String? = nil) {
        self.pid = pid
        self.name = name
        self.bundleID = bundleID
    }
}

extension JumpApp {
    /// One app per process the rows list, in the rows' order — a
    /// snapshot built with no strip of its own, as a test's is.
    public static func listed(in entries: [JumpEntry]) -> [JumpApp] {
        var seen = Set<pid_t>()
        return entries.compactMap { entry in
            seen.insert(entry.pid).inserted
                ? JumpApp(pid: entry.pid, name: entry.app) : nil
        }
    }
}
