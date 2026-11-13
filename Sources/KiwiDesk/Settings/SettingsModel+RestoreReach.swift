import KiwiDeskCore

/// How far a Restore Defaults reaches (#3248 ▸ Ruling).
enum RestoreReach: Equatable {
    /// The edited profile alone; the shared base and every other
    /// profile keep what they hold.
    case here
    /// Every profile and the shared base: each shared seed goes back,
    /// whatever value a profile held.
    case everyProfile
}

/// The seeded rows a Restore Defaults puts back, keyed as the
/// family's reach table keys them (#3248).
struct RestoreSeeds<Value: Hashable & Sendable> {
    /// The seeds every profile shares: what "every profile" writes
    /// everywhere and what "who changed" is judged against.
    let seeds: [String: Value]
    /// The page's own keys before the restore, and after it.
    let before: [String: Value]
    let after: [String: Value]

    /// Keys whose page value the restore moved.
    var moved: Set<String> {
        Set(after.keys.filter { after[$0] != before[$0] })
    }

    /// Keys the restore took off the page.
    var dropped: Set<String> {
        Set(before.keys).subtracting(after.keys)
    }
}

extension SettingsModel {
    /// Stages a restore's reach on the draft (#3248) over `stored`,
    /// the family's table before any row edit. `.here` keeps each
    /// moved key on the edited profile and leaves each dropped one
    /// out there. `.everyProfile` shares every shared seed with all
    /// profiles, and keeps a moved row no seed shares on the edited
    /// profile, as `.here` does. A pick the stored reach already
    /// answers is cleared rather than staged, so a restore nobody
    /// else shares leaves no reach of its own in the draft. A dropped
    /// row is the edited profile's under both answers: a seed taking
    /// its chord elsewhere is the encoder's take-over. Nothing is
    /// staged without a checklist.
    func stageRestore<Value>(
        _ family: RuleFamily,
        _ restore: RestoreSeeds<Value>,
        stored: RuleReachTable<Value>?,
        reach: RestoreReach
    ) {
        guard let stored, let editing = reachProfile else { return }
        let alone = RuleReach.listed([editing])
        let sharing = reach == .everyProfile ? restore.seeds : [:]
        for key in restore.moved where sharing[key] == nil {
            // A pick the stored reach already answers is cleared, so
            // an earlier pick on the row cannot carry the restore.
            let answered =
                stored.defaultReach(
                    of: key,
                    editing: editing,
                    isLoaded: reachIsLoaded
                ) == alone
            reachEdits.reach[family, default: [:]][key] =
                answered ? nil : alone
        }
        for key in sharing.keys {
            reachEdits.reach[family, default: [:]][key] =
                .everyProfile(stored.profiles)
        }
        for key in restore.dropped
        where stored.resolved(key, for: editing) != nil
            && (stored.base[key] != nil
                || stored.reach(of: key, editing: editing) != alone)
        {
            reachEdits.reach[family]?[key] = nil
            recordRemoval(family, key, .here)
        }
    }
}
