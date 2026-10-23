import Foundation
import KiwiDeskCore

/// Where a binding of the user's own is listed (#2544 ▸ Ruling): a
/// built-in group's token files it there, any other name into a
/// group of its own after the built-in ones, and none into Custom.
extension ShortcutsReferenceBuilder {
    struct Filed {
        var controls: [ShortcutSubgroup]
        var apps: [ShortcutRow]
        var groups: [ShortcutSubgroup]
        var custom: [ShortcutRow]
    }

    /// Files `own` into the built-in `controls` and `apps`, the
    /// user's groups and Custom, first moving each recognised row
    /// `moves` names out of a band other than its group; built-in
    /// groups left empty drop.
    static func file(
        _ own: [OwnRow],
        controls: [ShortcutSubgroup],
        apps: [ShortcutRow],
        moves: [String: ShortcutGroup] = [:]
    ) -> Filed {
        var filed = Filed(
            controls: controls,
            apps: apps,
            groups: [],
            custom: []
        )
        var moved: [OwnRow] = []
        // A folded row moves when every member names one group.
        func leaves(_ row: ShortcutRow, _ band: ShortcutGroup?) -> Bool {
            let ids = row.members.isEmpty ? [row.id] : row.members.map(\.id)
            let groups = Set(ids.map { moves[$0] })
            guard groups.count == 1, let group = groups.first ?? nil,
                group != band
            else { return false }
            moved.append(OwnRow(row: row, group: group.rawValue))
            return true
        }
        for index in filed.controls.indices {
            let band = filed.controls[index].group
            filed.controls[index].rows.removeAll { leaves($0, band) }
        }
        filed.apps.removeAll { leaves($0, .apps) }
        for entry in moved + own {
            switch ShortcutGroup.filing(entry.group) {
            case .none:
                filed.custom.append(entry.row)
            case .builtIn(.apps):
                filed.apps.append(entry.row)
            case .builtIn(let builtIn):
                if let index = filed.controls.firstIndex(
                    where: { $0.group == builtIn }
                ) {
                    filed.controls[index].rows.append(entry.row)
                } else {
                    filed.custom.append(entry.row)
                }
            case .own(let name):
                if let index = filed.groups.firstIndex(
                    where: { $0.title == name }
                ) {
                    filed.groups[index].rows.append(entry.row)
                } else {
                    filed.groups.append(
                        ShortcutSubgroup(title: name, rows: [entry.row])
                    )
                }
            }
        }
        filed.controls.removeAll { $0.rows.isEmpty }
        return filed
    }
}
