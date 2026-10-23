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
    /// user's groups and Custom; built-in groups left empty drop.
    static func file(
        _ own: [OwnRow],
        controls: [ShortcutSubgroup],
        apps: [ShortcutRow]
    ) -> Filed {
        var filed = Filed(
            controls: controls,
            apps: apps,
            groups: [],
            custom: []
        )
        for entry in own {
            let name = entry.group.trimmingCharacters(in: .whitespaces)
            if name.isEmpty {
                filed.custom.append(entry.row)
            } else if let builtIn = ShortcutGroup.builtIn(name) {
                if builtIn == .apps {
                    filed.apps.append(entry.row)
                } else if let index = filed.controls.firstIndex(
                    where: { $0.group == builtIn }
                ) {
                    filed.controls[index].rows.append(entry.row)
                } else {
                    filed.custom.append(entry.row)
                }
            } else if let index = filed.groups.firstIndex(
                where: { $0.title == name }
            ) {
                filed.groups[index].rows.append(entry.row)
            } else {
                filed.groups.append(
                    ShortcutSubgroup(title: name, rows: [entry.row])
                )
            }
        }
        filed.controls.removeAll { $0.rows.isEmpty }
        return filed
    }
}
