import KiwiDeskCore

/// The words a Restore Defaults asks with (#3248), shared by the
/// gesture cards and Shortcuts' Restore….
@MainActor
enum RestoreReachWords {
    /// Who else changed the seeded rows: by name while the
    /// `RuleReachWords.group` ladder names them, as a count past that.
    static func changedIn(_ profiles: [String]) -> String {
        if RuleReachWords.namesEach(profiles) {
            return L(
                "restore_reach.changed_in",
                "Changed in %1$@.",
                RuleReachWords.group(profiles)
            )
        }
        return L(
            "restore_reach.changed_in_count",
            "Changed in profiles: %1$d",
            profiles.count
        )
    }

    /// What "every profile" also removes from the other profiles: the
    /// user's rows on chords a seed takes over. A count, last.
    static func lostElsewhere(_ count: Int) -> String {
        L(
            "restore_reach.lost_elsewhere",
            "\u{201C}%1$@\u{201D} also removes your own shortcuts in "
                + "other profiles: %2$d",
            everyProfile,
            count
        )
    }

    /// The default answer: the edited profile alone.
    static func here(_ profile: String) -> String {
        L("restore_reach.here", "Restore in %1$@", profile)
    }

    static var everyProfile: String {
        L("restore_reach.every_profile", "Restore in every profile")
    }
}
