import Foundation

/// 4.2's slide and fade, written where a `gui.json` or a bundle's
/// `config` stores the app-wide groups but leaves the slide or the
/// fade out (#3254): the absence meant 300 ms, and Medium's 400 ms
/// default would otherwise answer for it, so #3237's crossing could
/// not tell an untouched install. A file before #1741 stores no
/// app-wide group and is left alone; `init.lua` is not reached
/// (`PaceAbsenceMigrationTests`).
extension ConfigMigration {
    /// The formats this step introduced, per shape, spelled as history.
    static let paceAbsenceGuiFormat = 25
    static let paceAbsenceBundleFormat = 49

    /// The two leaves, and the length their absence meant: 4.2's.
    static let absentPaceLeaves = [
        ("space", "slide_duration", AnimationPacePreset.legacyDefaults.slide),
        (
            "kiwivision", "fade_duration",
            AnimationPacePreset.legacyDefaults.fade
        ),
    ]

    @Sendable
    static func migratingAbsentSlideAndFade(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            gate: belowPaceAbsenceFloor,
            rewriting: withSlideAndFadeStated,
            editing: slideAndFadeTextStated
        )
    }

    /// The same leaves inserted as text into their groups, so the file
    /// keeps its shape; `surgicallyApplying` checks the result and
    /// re-serializes where an insert misses (a group absent, a group
    /// name repeated deeper).
    static func slideAndFadeTextStated(_ text: String) -> Data? {
        guard
            let root = try? JSONSerialization.jsonObject(
                with: Data(text.utf8)
            ) as? [String: Any]
        else { return nil }
        let config =
            root[SetupBundle.shapeMarker] != nil
            ? root["config"] as? [String: Any] : root
        guard let config else { return nil }
        var out = text
        for (group, key, length) in absentPaceLeaves {
            guard let leaves = config[group] as? [String: Any],
                leaves[key] == nil
            else { continue }
            out = insertingAfterEach(
                "\"\(key)\":\(length)",
                pattern: "(\"\(group)\"\\s*:\\s*\\{)(\\s*\\})?",
                in: out
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }

    private static func belowPaceAbsenceFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < paceAbsenceBundleFormat
        case .gui: return format < paceAbsenceGuiFormat
        case .profile, .palettes, .looks: return false
        }
    }

    /// `node` with the two leaves stated in a `gui.json` root or a
    /// bundle's `config`.
    static func withSlideAndFadeStated(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else { return (node, false) }
        guard root[SetupBundle.shapeMarker] != nil else {
            return statingSlideAndFade(root)
        }
        guard let config = root["config"] as? [String: Any] else {
            return (node, false)
        }
        let (stated, changed) = statingSlideAndFade(config)
        root["config"] = stated
        return (root, changed)
    }

    private static func statingSlideAndFade(
        _ config: [String: Any]
    ) -> ([String: Any], Bool) {
        // The #1741 marker: only a file that stores the groups.
        guard
            config[retiredRefusalGroup] != nil
                || config[retiredQuitGroup] != nil
        else {
            return (config, false)
        }
        var out = config
        var changed = false
        for (group, key, length) in absentPaceLeaves {
            var leaves = out[group] as? [String: Any] ?? [:]
            guard leaves[key] == nil else { continue }
            leaves[key] = length
            out[group] = leaves
            changed = true
        }
        return (out, changed)
    }
}
