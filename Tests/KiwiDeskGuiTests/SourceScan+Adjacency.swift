import Foundation

extension SourceScan {
    /// How many lines equal to `line` are directly followed —
    /// skipping blank lines — by a line equal to `follower`,
    /// both compared trimmed. Line-wise rather than a regex, so
    /// a match is a whole modifier on its own line and cannot be
    /// satisfied by a substring inside a longer expression.
    ///
    /// Promoted from a private helper in
    /// `SettingsLabelNeutralityTests` when the #771 suite split
    /// left a second guard file needing the same walk — the
    /// promotion the local copy's comment reserved for exactly
    /// this moment. The drift harm is the family's usual one: a
    /// hardened copy beside an unhardened one lets the wider
    /// copy count an adjacency its guard exists to refuse.
    static func adjacentPairs(
        in source: String,
        line: String,
        followedBy follower: String
    ) -> Int {
        let lines = source.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).map { $0.trimmingCharacters(in: .whitespaces) }
        var hits = 0
        for (i, current) in lines.enumerated()
        where current == line {
            var j = i + 1
            while j < lines.count, lines[j].isEmpty { j += 1 }
            if j < lines.count, lines[j] == follower {
                hits += 1
            }
        }
        return hits
    }
}
