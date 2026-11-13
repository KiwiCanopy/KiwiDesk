import KiwiDeskCore

/// How far a Restore Defaults reaches (#3248 ▸ Ruling).
enum RestoreReach: Equatable {
    /// The edited profile alone; the shared base and every other
    /// profile keep what they hold.
    case here
    /// Every profile and the shared base: each seeded row goes back
    /// to its seed, whatever value a profile held.
    case everyProfile
}

/// The seeded rows a Restore Defaults puts back, keyed as the
/// family's reach table keys them (#3248): what the restore writes
/// and how far, and who else it would change.
struct RestoreSeeds<Value: Hashable & Sendable> {
    /// Every seeded key and its seed.
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

    /// The profiles other than `editing` in which at least one
    /// seeded key resolves away from its seed — the union across
    /// the keys, in listing order.
    func changedElsewhere(
        in table: RuleReachTable<Value>,
        editing: String
    ) -> [String] {
        table.profiles.filter { profile in
            profile != editing
                && seeds.contains {
                    table.resolved($0.key, for: profile) != $0.value
                }
        }
    }
}

extension SettingsModel {
    /// Stages a restore's reach on the draft (#3248): `.here` writes
    /// each moved key to the edited profile alone and leaves each
    /// dropped one out there; `.everyProfile` shares every seed with
    /// every profile joining it. A dropped row is the edited
    /// profile's in both, since a seed taking its chord elsewhere is
    /// the encoder's take-over. Nothing is staged without a
    /// checklist.
    func stageRestore<Value>(
        _ family: RuleFamily,
        _ restore: RestoreSeeds<Value>,
        profiles: [String],
        reach: RestoreReach
    ) {
        guard let editing = reachProfile else { return }
        switch reach {
        case .here:
            for key in restore.moved {
                reachEdits.reach[family, default: [:]][key] =
                    .listed([editing])
            }
        case .everyProfile:
            for key in restore.seeds.keys {
                reachEdits.reach[family, default: [:]][key] =
                    .shared(joining: Set(profiles))
            }
        }
        for key in restore.dropped {
            reachEdits.reach[family]?[key] = nil
            recordRemoval(family, key, .here)
        }
    }
}

/// The words a Restore Defaults asks with (#3248).
@MainActor
enum RestoreReachWords {
    /// Who else changed the seeded rows: by name for one or two,
    /// as a count past that.
    static func changedIn(_ profiles: [String]) -> String {
        if profiles.count <= 2 {
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

    /// The default answer: the edited profile alone.
    static func here(_ profile: String) -> String {
        L("restore_reach.here", "Restore in %1$@", profile)
    }

    static var everyProfile: String {
        L("restore_reach.every_profile", "Restore in every profile")
    }
}
