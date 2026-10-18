import KiwiDeskCore

extension ProfilesFamilyRows {
    /// The card's groups over its Desktop rows: `rows` once per
    /// count, then the orphans — each bound entry naming no saved
    /// profile, by its label, on the row it is bound to.
    static func bindingGroups(
        rows: [DesktopRow],
        counts: BindingCounts,
        resolver: BindingResolver
    ) -> [BindingGroup] {
        var groups = counts.all.map {
            BindingGroup.count($0, leads: $0 == counts.leading, rows: rows)
        }
        let orphans = rows.flatMap { row in
            let orphans = (row.binding?.entries ?? [])
                .filter { resolver.name(of: $0) == nil }
            return unique(orphans.map(\.name)).map { name in
                OrphanBinding(
                    row: row,
                    profile: name,
                    unreadable: orphans.contains {
                        $0.name == name && resolver.isUnreadable($0)
                    }
                )
            }
        }
        if !orphans.isEmpty { groups.append(.orphans(orphans)) }
        return groups
    }

    /// `labels` once each, in order.
    fileprivate static func unique(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        return labels.filter { seen.insert($0).inserted }
    }
}
