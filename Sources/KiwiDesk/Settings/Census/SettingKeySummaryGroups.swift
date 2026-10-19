import KiwiDeskCore

/// Settings one control writes together, narrated as that control
/// while they agree (#2450): the save pill and the sync sheet fold
/// a group's changed members into its master once every axis of
/// the group holds one value, and list them apart otherwise. Unlike
/// `masterWrites`, the fold is conditional and the diff stays per
/// member, so key sets taken from different diffs keep comparing
/// at one granularity (`SettingsSummaryGroupTests`).
extension SettingKey {
    /// Each group's members by axis: a group agrees while every
    /// axis holds one value — the moment its master's own readout
    /// names one value rather than "mixed".
    static let summaryAxes: [SettingKey: [[SettingKey]]] = [
        .gaps(.outer): [
            [
                .gaps(.outerTop), .gaps(.outerBottom),
                .gaps(.outerLeft), .gaps(.outerRight),
            ]
        ],
        .gaps(.inner): [[.gaps(.innerHorizontal), .gaps(.innerVertical)]],
        .behaviour(.minWindowSize): [
            [
                .behaviour(.minSizeStackWidth),
                .behaviour(.minSizeGridWidth),
                .behaviour(.minSizeTrackWidth),
                .behaviour(.minSizeBspWidth),
                .behaviour(.minSizeScrollingWidth),
                .behaviour(.minSizeFloatingWidth),
            ],
            [
                .behaviour(.minSizeStackHeight),
                .behaviour(.minSizeGridHeight),
                .behaviour(.minSizeTrackHeight),
                .behaviour(.minSizeBspHeight),
                .behaviour(.minSizeScrollingHeight),
                .behaviour(.minSizeFloatingHeight),
            ],
        ],
    ]

    /// Each group's members, every axis in order.
    static var summaryGroups: [SettingKey: [SettingKey]] {
        summaryAxes.mapValues { $0.flatMap { $0 } }
    }

    /// The group `self` is a member of.
    var summaryMaster: SettingKey? {
        Self.summaryAxes.first { $0.value.joined().contains(self) }?.key
    }

    /// Whether every axis of `master`'s group holds one value in
    /// `config`.
    static func summarizes(
        _ master: SettingKey,
        in config: GuiConfig
    ) -> Bool {
        guard let axes = summaryAxes[master] else { return false }
        let leaves = SettingsDraftDiff.leaves(of: config)
        return axes.allSatisfy { axis in
            Set(axis.map { leaves[$0.id] }).count == 1
        }
    }

    /// `keys` with each group whose members all agree in `config`
    /// narrated as its master, at its first member's place. A group
    /// with a member in `apart` — narrated elsewhere — never folds;
    /// every caller states it, `[]` included.
    static func summarized(
        _ keys: [SettingKey],
        in config: GuiConfig,
        apart: Set<SettingKey>
    ) -> [SettingKey] {
        var folded: [SettingKey: Bool] = [:]
        var result: [SettingKey] = []
        for key in keys {
            guard let master = key.summaryMaster else {
                result.append(key)
                continue
            }
            let folds =
                folded[master]
                ?? (summaryGroups[master, default: []]
                    .allSatisfy { !apart.contains($0) }
                    && summarizes(master, in: config))
            if folded[master] == nil, folds { result.append(master) }
            folded[master] = folds
            if !folds { result.append(key) }
        }
        return result
    }
}
