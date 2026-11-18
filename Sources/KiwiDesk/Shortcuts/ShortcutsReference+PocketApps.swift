import Foundation
import KiwiDeskCore

/// The Apps band's launch keys, and each app's Pocket key (#2612),
/// read by the one `PocketAppLuaArg` shape Core reads and listed
/// with the Pocket's other keys (#3449).
extension ShortcutsReferenceBuilder {
    /// The band's launch rows sorted by app name (#334).
    static func buildApps(
        _ layer: KeyLayer,
        consumed: inout Set<UUID>
    ) -> [ShortcutRow] {
        buildLaunchRows(layer, consumed: &consumed).sorted(by: byAppName)
    }

    /// An app's Pocket key (#2612): its icon, "Pocket ‹app›", so the
    /// label tells it from the app's Open key in sight, in search and
    /// in speech. Sorted by app name.
    static func buildPocketAppRows(
        _ layer: KeyLayer,
        consumed: inout Set<UUID>
    ) -> [ShortcutRow] {
        layer.bindings.compactMap { binding -> ShortcutRow? in
            guard !binding.combo.isEmpty,
                let bundleID = PocketAppLuaArg.bundleID(of: binding.lua)
            else { return nil }
            consumed.insert(binding.id)
            let name = KeybindingCatalog.displayName(forBundleID: bundleID)
            return ShortcutRow(
                id: binding.id.uuidString,
                label: binding.desc.isEmpty
                    ? KeybindingCatalog.pocketApp(bundleID).resolvedLabel
                    : binding.desc,
                combo: glyphs(binding.combo),
                bundleID: bundleID,
                appName: name
            )
        }
        .sorted(by: byAppName)
    }

    /// Orders app rows by the app's name, then id for a stable tie
    /// (#334): never by a title naming the action (#3448).
    static func byAppName(_ lhs: ShortcutRow, _ rhs: ShortcutRow) -> Bool {
        let order = (lhs.appName ?? lhs.label)
            .localizedCaseInsensitiveCompare(rhs.appName ?? rhs.label)
        if order != .orderedSame { return order == .orderedAscending }
        return lhs.id < rhs.id
    }

    /// Lists `pocketApps` right under the Pocket's own rows (#3449 ▸
    /// Ruling): in Size & float, or in the group a binding files the
    /// last of them into (#2544); at Size & float's foot when no
    /// Pocket row is bound.
    static func filingPocketApps(
        _ pocketApps: [ShortcutRow],
        controls: inout [ShortcutSubgroup],
        regrouped: inout [OwnRow]
    ) {
        guard !pocketApps.isEmpty else { return }
        if let last = regrouped.lastIndex(where: \.row.pocketMark) {
            let group = regrouped[last].group
            regrouped.insert(
                contentsOf: pocketApps.map { OwnRow(row: $0, group: group) },
                at: last + 1
            )
            return
        }
        guard
            let band = controls.firstIndex(where: { $0.group == .sizeFloat })
        else { return }
        let rows = controls[band].rows
        let at = rows.lastIndex(where: \.pocketMark).map { $0 + 1 }
        controls[band].rows.insert(
            contentsOf: pocketApps,
            at: at ?? rows.endIndex
        )
    }
}
