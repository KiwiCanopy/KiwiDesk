import Foundation

extension RuleReachTable {
    /// Profiles other than `editing` in which at least one of
    /// `seeds`' keys resolves away from its seed (#3248): the union
    /// over the keys, in listing order, so a Restore Defaults asks
    /// once and names everyone it could change.
    public func profilesAway(
        from seeds: [String: Value],
        editing: String
    ) -> [String] {
        profiles.filter { profile in
            profile != editing
                && seeds.contains {
                    resolved($0.key, for: profile) != $0.value
                }
        }
    }
}

extension RuleReachTable where Value == String {
    /// What sharing `seeds` with every profile takes from the others
    /// (#3248): per profile other than `editing`, the count of its
    /// own rows outside the seeds that it resolves now and no longer
    /// once each seed is written as a Save writes it — a row on a
    /// chord a seed takes over. Profiles that lose nothing are
    /// absent.
    public func lostSharing(
        _ seeds: [String: String],
        editing: String
    ) -> [String: Int] {
        var after = self
        for (key, value) in seeds {
            after.applyKey(
                key,
                value: value,
                reach: .shared(joining: Set(profiles)),
                editing: editing
            )
        }
        var lost: [String: Int] = [:]
        for profile in profiles where profile != editing {
            let gone = resolved(for: profile).keys.filter {
                seeds[$0] == nil && after.resolved($0, for: profile) == nil
            }
            if !gone.isEmpty { lost[profile] = gone.count }
        }
        return lost
    }
}
