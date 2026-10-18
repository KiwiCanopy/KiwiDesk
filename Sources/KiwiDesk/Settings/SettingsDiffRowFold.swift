import KiwiDeskCore

/// The rule a diff row changes: a family and the key its reach
/// table files the subject under (`RuleFamily.key`).
struct ReachSubject: Hashable {
    let family: RuleFamily
    let key: String
}

/// Profiles that changed exactly as the edited one did read as its
/// row's reach rather than a row each (#792, owner 2026-10-18).
@MainActor
enum SettingsDiffRowFold {
    /// `own` with every folding reach row's words drawn on the own
    /// row of its subject, followed by the reach rows left over.
    static func folded(
        _ own: [SettingsDiffRow],
        reach: [SettingsDiffRow]
    ) -> [SettingsDiffRow] {
        var own = own
        var rest: [SettingsDiffRow] = []
        for row in reach {
            guard let words = row.foldReach, let subject = row.subject,
                let at = own.firstIndex(where: {
                    $0.subject == subject && $0.reach == nil
                })
            else {
                rest.append(row)
                continue
            }
            own[at].reach = words
        }
        return own + rest
    }
}
