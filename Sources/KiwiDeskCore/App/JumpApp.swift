import Foundation

/// One tile of KiwiHub's app strip (#3135): an app the Windows
/// side lists, by the process that owns its rows. Core names the
/// app; the GUI draws the tile and counts its rows from the
/// snapshot's entries, so a count is never a second reading.
public struct JumpApp: Sendable, Equatable {
    public let pid: pid_t
    public let name: String

    public init(pid: pid_t, name: String) {
        self.pid = pid
        self.name = name
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

/// A running regular app by bundle id, for KiwiHub's Applications
/// section (#3704): Core names which apps run and which of them
/// hold a row; the GUI ranks them with the installed ones.
public struct JumpRunningApp: Sendable, Equatable {
    /// Lowercased, as every app verb takes it.
    public let bundleID: String
    public let name: String
    /// Whether a row of the list, or the current window, is its, or
    /// KiwiDesk ignores the app: either way the section leaves it
    /// out.
    public let listed: Bool

    public init(bundleID: String, name: String, listed: Bool) {
        self.bundleID = bundleID
        self.name = name
        self.listed = listed
    }
}
