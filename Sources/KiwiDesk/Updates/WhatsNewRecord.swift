import Foundation

/// When "What's new" is owed (#1542 ruling ▸ After the update): on
/// the first launch of a newer version whose notes the user did
/// not already read in the update window. Kept in the app's own
/// defaults — per machine, never in a backup (owner, 2026-09-24),
/// so restoring one cannot replay or suppress it.
struct WhatsNewRecord {
    /// `CFBundleVersion` of the last launch that owed nothing, or
    /// whose "What's new" was answered.
    static let lastRunKey = "updates.lastRunVersion"
    /// The version installed from the update window's own Install:
    /// its notes were read there, so none are owed after it.
    static let seenKey = "updates.notesSeenVersion"

    let defaults: UserDefaults

    init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastRun: String? { defaults.string(forKey: Self.lastRunKey) }
    var seen: String? { defaults.string(forKey: Self.seenKey) }

    func markSeen(_ version: String) {
        defaults.set(version, forKey: Self.seenKey)
    }

    /// The owed range is answered: this version's notes are done.
    func markAnswered(_ version: String) {
        defaults.set(version, forKey: Self.lastRunKey)
    }

    /// What a launch owes. `existingUser` tells a 1.x upgrade —
    /// which never wrote `lastRun` — from a fresh install, whose
    /// welcome is the tour.
    static func due(
        current: String,
        lastRun: String?,
        seen: String?,
        existingUser: Bool,
        compare: (String, String) -> ComparisonResult
    ) -> WhatsNewDue? {
        guard seen != current else { return nil }
        guard let lastRun else {
            return existingUser ? WhatsNewDue(since: nil) : nil
        }
        guard compare(current, lastRun) == .orderedDescending
        else { return nil }
        return WhatsNewDue(since: lastRun)
    }
}

/// "What's new" is owed for everything after `since`; nil is a
/// 1.x upgrade, whose starting version was never recorded.
struct WhatsNewDue: Equatable {
    let since: String?
}
