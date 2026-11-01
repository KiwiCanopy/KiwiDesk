import Foundation
import KiwiDeskCore

/// The Apps band: launch keys and each app's Pocket key (#2612),
/// the latter read by the one `PocketAppLuaArg` shape Core reads.
extension ShortcutsReferenceBuilder {
    /// The band's rows sorted by app name (#334), each app's Pocket
    /// key directly after its own launch key (#2612).
    static func buildApps(
        _ layer: KeyLayer,
        consumed: inout Set<UUID>
    ) -> [ShortcutRow] {
        let launch = buildLaunchRows(layer, consumed: &consumed)
            .map { (name: $0.label, pocket: false, row: $0) }
        let pocket = buildPocketAppRows(layer, consumed: &consumed)
        return (launch + pocket)
            .sorted { lhs, rhs in
                let order = lhs.name
                    .localizedCaseInsensitiveCompare(rhs.name)
                if order != .orderedSame {
                    return order == .orderedAscending
                }
                if lhs.pocket != rhs.pocket { return rhs.pocket }
                return lhs.row.id < rhs.row.id
            }
            .map(\.row)
    }

    /// An app's Pocket key (#2612): its icon, "Pocket ‹app›", so the
    /// label tells it from the app's Open key in sight, in search and
    /// in speech.
    static func buildPocketAppRows(
        _ layer: KeyLayer,
        consumed: inout Set<UUID>
    ) -> [(name: String, pocket: Bool, row: ShortcutRow)] {
        layer.bindings.compactMap { binding in
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
            return (name, true, row)
        }
    }
}
