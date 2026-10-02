import AppKit

/// One icon per running process for the bars (#1901): reading it
/// is a LaunchServices round trip, and a fresh `NSImage` on every
/// render made two identical renders compare unequal. A nil is
/// never kept — a process can lack its LaunchServices record for
/// a moment after launch — and an exit forgets the pid
/// (`KiwiCore.handle`), so a reused pid reads afresh.
@MainActor
enum BarIconCache {
    private static var icons: [pid_t: NSImage] = [:]

    /// The process's icon, read once.
    static func icon(pid: pid_t) -> NSImage? {
        if let cached = icons[pid] { return cached }
        guard
            let icon = NSRunningApplication(processIdentifier: pid)?
                .icon
        else { return nil }
        icons[pid] = icon
        return icon
    }

    /// Drops an exited process's icon.
    static func forget(pid: pid_t) {
        icons[pid] = nil
    }
}
