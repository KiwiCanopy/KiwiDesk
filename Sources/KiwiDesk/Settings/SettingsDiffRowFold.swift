import KiwiDeskCore

/// The rule a diff row changes: a family and the key its reach
/// table files the subject under (`RuleFamily.key`).
struct ReachSubject: Hashable {
    let family: RuleFamily
    let key: String
}

/// Profiles that changed exactly as the edited one did read as its
/// rows' reach rather than a row each (#792, owner 2026-10-18).
@MainActor
enum SettingsDiffRowFold {
    /// `own` with each folding reach row's words drawn on EVERY own
    /// row of its subject — a float rule's Added and Removed notes
    /// alike — followed by the reach rows left over, which draw
    /// none: their profiles are their label.
    static func folded(
        _ own: [SettingsDiffRow],
        reach: [SettingsDiffRow]
    ) -> [SettingsDiffRow] {
        var own = own
        var rest: [SettingsDiffRow] = []
        for var row in reach {
            let matches = own.indices.filter {
                guard let subject = row.subject else { return false }
                return own[$0].subject == subject
                    || own[$0].pairedSubject == subject
            }
            // A paired row already naming other words keeps them, and
            // this reach row stays its own (#3225).
            guard let words = row.reach, !matches.isEmpty,
                matches.allSatisfy({ (own[$0].reach ?? words) == words })
            else {
                row.reach = nil
                rest.append(row)
                continue
            }
            for at in matches { own[at].reach = words }
        }
        return own + rest
    }
}
