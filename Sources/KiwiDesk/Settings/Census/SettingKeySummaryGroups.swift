import KiwiDeskCore

/// Settings one control writes together, narrated as that control
/// while they agree (#2450): the save pill and the sync sheet fold
/// a group's changed members into its master once every member
/// holds one value, and list them apart otherwise. Unlike
/// `masterWrites`, the fold is conditional and the diff stays per
/// member, so key sets taken from different diffs keep comparing
/// at one granularity (`SettingsSummaryGroupTests`).
extension SettingKey {
    static let summaryGroups: [SettingKey: [SettingKey]] = [
        .gaps(.outer): [
            .gaps(.outerTop), .gaps(.outerBottom),
            .gaps(.outerLeft), .gaps(.outerRight),
        ],
        .gaps(.inner): [.gaps(.innerHorizontal), .gaps(.innerVertical)],
    ]

    /// The group `self` is a member of.
    var summaryMaster: SettingKey? {
        Self.summaryGroups.first { $0.value.contains(self) }?.key
    }

    /// Whether every member of `master`'s group holds one value in
    /// `config`.
    static func summarizes(
        _ master: SettingKey,
        in config: GuiConfig
    ) -> Bool {
        guard let members = summaryGroups[master] else { return false }
        let leaves = SettingsDraftDiff.leaves(of: config)
        return Set(members.map { leaves[$0.id] }).count == 1
    }

    /// `keys` with each group whose members all agree in `config`
    /// narrated as its master, at its first member's place.
    static func summarized(
        _ keys: [SettingKey],
        in config: GuiConfig
    ) -> [SettingKey] {
        var folded: [SettingKey: Bool] = [:]
        var result: [SettingKey] = []
        for key in keys {
            guard let master = key.summaryMaster else {
                result.append(key)
                continue
            }
            let folds =
                folded[master] ?? summarizes(master, in: config)
            if folded[master] == nil, folds { result.append(master) }
            folded[master] = folds
            if !folds { result.append(key) }
        }
        return result
    }
}
