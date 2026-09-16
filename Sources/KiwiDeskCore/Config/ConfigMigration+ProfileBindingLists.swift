import Foundation

/// Migrates a `profile_bindings` value's `profile` to the
/// per-count list `profiles` (#1436, `ConfigMigrationRoutingTests`,
/// `ProfileBindingListMigrationTests`):
/// `{"profile": "Work", "desktop": 2}` →
/// `{"profiles": ["Work"], "desktop": 2}`, every other key of the
/// record — `desktop`, `screen` — carried as it stands.
///
/// Runs after `migratingProfileBindingStrings`, so a format-1
/// file crosses both in one pass. Strict decoder, so without this
/// step a gui.json from any earlier build fails to decode as a
/// UNIT (AGENTS.md §5).
extension ConfigMigration {
    /// Spelled here rather than derived from `DesktopBinding`: a
    /// historical step keeps emitting the names it was written to
    /// emit, so a LATER rename composes on top.
    static let bindingProfilesKey = "profiles"

    /// Rewrites single-profile binding records as lists.
    @Sendable
    static func migratingProfileBindingLists(
        _ data: Data
    ) -> Data? {
        let needle = Data("\"\(profileBindingsKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { $0.range(of: needle) != nil },
            rewriting: bindingsListed,
            // No textual edit: the rewrite moves a scalar into an
            // array, which is a tree edit however it is spelled.
            editing: { _ in nil }
        )
    }

    /// Every `profile_bindings` map's values listed, at any
    /// depth — a `SetupBundle` carries `config` inline.
    static func bindingsListed(_ node: Any) -> (Any, Bool) {
        rewritingValues(
            of: node,
            at: profileBindingsKey,
            listedBindings
        )
    }

    /// The map's own rewrite, or nil when no record still carries
    /// a scalar `profile` — a map already listed is left
    /// untouched so a second pass rewrites nothing.
    private static func listedBindings(_ value: Any) -> Any? {
        guard let map = value as? [String: Any],
            map.values.contains(where: {
                ($0 as? [String: Any])?[bindingProfileKey] is String
            })
        else { return nil }
        var out: [String: Any] = [:]
        for (key, entry) in map {
            guard var record = entry as? [String: Any],
                let profile = record[bindingProfileKey] as? String
            else {
                out[key] = entry
                continue
            }
            record[bindingProfileKey] = nil
            record[bindingProfilesKey] = [profile]
            out[key] = record
        }
        return out
    }
}
