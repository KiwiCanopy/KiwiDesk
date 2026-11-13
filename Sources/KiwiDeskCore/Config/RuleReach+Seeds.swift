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
