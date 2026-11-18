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
        buildLaunchRows(layer, consumed: &consumed)
            .sorted { lhs, rhs in
                let order = lhs.label
                    .localizedCaseInsensitiveCompare(rhs.label)
                if order != .orderedSame {
                    return order == .orderedAscending
                }
                return lhs.id < rhs.id
            }
    }

    /// An app's Pocket key (#2612): its icon, "Pocket ‹app›", so the
    /// label tells it from the app's Open key in sight, in search and
    /// in speech. Sorted by app name.
    static func buildPocketAppRows(
        _ layer: KeyLayer,
        consumed: inout Set<UUID>
    ) -> [ShortcutRow] {
        let named = layer.bindings.compactMap {
            binding -> (name: String, row: ShortcutRow)? in
            guard !binding.combo.isEmpty,
                let bundleID = PocketAppLuaArg.bundleID(of: binding.lua)
            else { return nil }
            consumed.insert(binding.id)
            let name = KeybindingCatalog.displayName(forBundleID: bundleID)
            let row = ShortcutRow(
                id: binding.id.uuidString,
                label: binding.desc.isEmpty
                    ? KeybindingCatalog.pocketApp(bundleID).resolvedLabel
                    : binding.desc,
                combo: glyphs(binding.combo),
                bundleID: bundleID
            )
            return (name, row)
        }
        return named.sorted { lhs, rhs in
            let order = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if order != .orderedSame { return order == .orderedAscending }
            return lhs.row.id < rhs.row.id
        }
        .map(\.row)
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
