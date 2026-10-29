import Foundation

/// Stamps every profile written before ids existed with
/// `ProfileID.legacy(name:)` (#2324 ruling 11, `ProfileIDTests`):
/// deterministic, so two Macs migrating one shared file write the
/// same bytes, and a binding stored by name resolves to it.
///
/// It reaches a profile file and a bundle's inline profiles, the
/// two shapes that carry `Profile`; `gui.json` carries none.
extension ConfigMigration {
    /// The profile format that introduced `id`.
    static let profileIDProfileFormat = 23
    /// The bundle format that carries it on its inline profiles.
    static let profileIDBundleFormat = 29

    /// Spelled rather than derived: a historical step keeps
    /// emitting what it was written to emit.
    static let profileIDKey = "id"

    @Sendable
    static func migratingProfileIDs(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: profileIDProfileFormat,
                bundle: profileIDBundleFormat
            )
        else { return nil }
        return surgicallyApplying(
            data,
            rewriting: stampingProfileIDs,
            editing: surgicallyStampingProfileID
        )
    }

    private static func legacyID(of profile: [String: Any]) -> String? {
        (profile["name"] as? String).map {
            ProfileID.legacy(name: $0).raw
        }
    }

    /// A profile root or a bundle's `profiles`, each given its
    /// legacy id where it carries none.
    private static func stampingProfileIDs(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        let shape = shape(of: root)
        if shape == .bundle {
            guard var profiles = root["profiles"] as? [[String: Any]]
            else { return (node, false) }
            var changed = false
            for index in profiles.indices
            where profiles[index][profileIDKey] == nil {
                guard let id = legacyID(of: profiles[index]) else {
                    continue
                }
                profiles[index][profileIDKey] = id
                changed = true
            }
            root["profiles"] = profiles
            return (root, changed)
        }
        guard shape == .profile, root[profileIDKey] == nil,
            let id = legacyID(of: root)
        else { return (node, false) }
        root[profileIDKey] = id
        return (root, true)
    }

    /// A profile file's text with its id inserted after the root's
    /// opening brace, in the file's own layout. A bundle's inline
    /// profiles take the parsed rewrite instead (nil here).
    private static func surgicallyStampingProfileID(
        _ text: String
    ) -> Data? {
        guard !text.contains("\"\(SetupBundle.shapeMarker)\""),
            let root = try? JSONSerialization.jsonObject(
                with: Data(text.utf8)
            ) as? [String: Any],
            let id = legacyID(of: root),
            let brace = text.range(of: "{")
        else { return nil }
        let entry = "\"\(profileIDKey)\""
        let after = text[brace.upperBound...]
        var out = text
        if after.hasPrefix("\r\n") || after.hasPrefix("\n") {
            out.insert(
                contentsOf: "\n  \(entry) : \"\(id)\",",
                at: brace.upperBound
            )
        } else {
            out.insert(
                contentsOf: "\(entry):\"\(id)\",",
                at: brace.upperBound
            )
        }
        return out.data(using: .utf8)
    }
}
