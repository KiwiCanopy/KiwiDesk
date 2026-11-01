import Foundation
import KiwiDeskCore

/// The Apps band's per-app Pocket keys (#2612), read by the one
/// `PocketAppLuaArg` shape Core reads.
extension ShortcutsReferenceBuilder {
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
