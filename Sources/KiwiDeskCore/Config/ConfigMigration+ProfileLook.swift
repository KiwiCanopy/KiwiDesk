import Foundation

/// Stamps `look: own` into every profile written before #1752
/// (`ConfigMigrationRoutingTests`, `ProfileLookOwnMigrationTests`):
/// an absent `look` now means the shared look, so without the
/// stamp every existing profile would silently start wearing a
/// look it never chose. The crossing (`KiwiCore+SharedLook`) then
/// lets a profile that already wears the shared look follow it.
///
/// It reaches a profile file and a bundle's inline profiles, the
/// two shapes that carry `Profile`; `gui.json` carries none.
extension ConfigMigration {
    /// The profile format that made an absent `look` mean shared.
    static let profileLookFormat = 13
    /// The bundle format that carries it on its inline profiles.
    static let profileLookBundleFormat = 18

    /// Spelled rather than derived: a historical step keeps
    /// emitting what it was written to emit.
    static let profileLookKey = "look"
    static let profileLookOwn = "own"

    @Sendable
    static func migratingProfileLookOwn(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: profileLookFormat,
                bundle: profileLookBundleFormat
            )
        else { return nil }
        return surgicallyApplying(
            data,
            rewriting: stampingOwnLook,
            editing: surgicallyStampingOwnLook
        )
    }

    /// A profile root — told by its monitor sets, as
    /// `targetFormat` tells it — or a bundle's `profiles`, each
    /// given `own` where it states no look.
    private static func stampingOwnLook(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        if root[SetupBundle.shapeMarker] != nil {
            guard var profiles = root["profiles"] as? [[String: Any]]
            else { return (node, false) }
            var changed = false
            for index in profiles.indices
            where profiles[index][profileLookKey] == nil {
                profiles[index][profileLookKey] = profileLookOwn
                changed = true
            }
            root["profiles"] = profiles
            return (root, changed)
        }
        let isProfile =
            root[Profile.CodingKeys.monitorSets.rawValue] != nil
            || root["monitorSets"] != nil
        guard isProfile, root[profileLookKey] == nil else {
            return (node, false)
        }
        root[profileLookKey] = profileLookOwn
        return (root, true)
    }

    /// A profile file's text with `look: own` inserted after its
    /// root's opening brace, in the file's own layout, so nothing
    /// else in it is re-encoded. A bundle's inline profiles take
    /// the parsed rewrite instead (nil here).
    private static func surgicallyStampingOwnLook(
        _ text: String
    ) -> Data? {
        guard !text.contains("\"\(SetupBundle.shapeMarker)\""),
            let brace = text.range(of: "{")
        else { return nil }
        let entry = "\"\(profileLookKey)\""
        let after = text[brace.upperBound...]
        var out = text
        if after.hasPrefix("\r\n") || after.hasPrefix("\n") {
            out.insert(
                contentsOf: "\n  \(entry) : \"\(profileLookOwn)\",",
                at: brace.upperBound
            )
        } else {
            out.insert(
                contentsOf: "\(entry):\"\(profileLookOwn)\",",
                at: brace.upperBound
            )
        }
        return out.data(using: .utf8)
    }
}
