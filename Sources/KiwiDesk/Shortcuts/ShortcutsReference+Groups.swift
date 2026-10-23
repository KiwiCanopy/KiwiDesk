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
    /// user's groups and Custom, folding the rows each one gains;
    /// built-in groups left empty drop.
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
        let built = controls.map(\.rows.count)
        let builtApps = apps.count
        for entry in own {
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
        // A recognised fold that moved whole folds again where it
        // lands; the rows a band was built with are folded already.
        func foldingGained(_ rows: [ShortcutRow], after kept: Int)
            -> [ShortcutRow]
        {
            Array(rows.prefix(kept))
                + ShortcutFold.folded(Array(rows.dropFirst(kept)))
        }
        for index in filed.controls.indices {
            filed.controls[index].rows = foldingGained(
                filed.controls[index].rows,
                after: built[index]
            )
        }
        filed.apps = foldingGained(filed.apps, after: builtApps)
        for index in filed.groups.indices {
            filed.groups[index].rows = ShortcutFold.folded(
                filed.groups[index].rows
            )
        }
        filed.controls.removeAll { $0.rows.isEmpty }
        return filed
    }
}
