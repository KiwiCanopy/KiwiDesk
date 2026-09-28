import Foundation

/// The retired per-profile spelling of the app-wide settings
/// (#1741): read once by `KiwiCore.prepareAppWide`, and dropped
/// from every profile file when the crossing ends.
extension ConfigMigration {
    /// The retired groups under a profile's `settings`, spelled
    /// here rather than derived: `TilingSettings` no longer
    /// declares them.
    static let retiredRefusalGroup = "refusal"
    static let retiredQuitGroup = "quit"

    /// The values a profile file carries under the retired groups,
    /// nil when it carries neither.
    static func legacyAppWide(inProfile data: Data) -> AppWideSettings? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let settings = root[glassSettingsKey] as? [String: Any]
        else { return nil }
        let refusal = settings[retiredRefusalGroup] as? [String: Any]
        let quit = settings[retiredQuitGroup] as? [String: Any]
        let sound = refusal?["sound"] as? Bool
        let depth = quit?["grid_target_depth"] as? Int
        let layout = (quit?["layout"] as? String)
            .flatMap(QuitLayoutStyle.init(rawValue:))
        guard sound != nil || depth != nil || layout != nil
        else { return nil }
        return AppWideSettings(
            refusal: .init(sound: sound),
            quit: .init(gridTargetDepth: depth, layout: layout)
        )
    }

    /// The retired values each profile inside a backup carries, by
    /// profile name — a bundle is the second reader of that shape.
    static func legacyAppWide(
        inBundle data: Data
    ) -> [String: AppWideSettings] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let profiles = root["profiles"] as? [[String: Any]]
        else { return [:] }
        var out: [String: AppWideSettings] = [:]
        for profile in profiles {
            guard let name = profile["name"] as? String,
                let bytes = try? JSONSerialization.data(
                    withJSONObject: profile
                ),
                let legacy = legacyAppWide(inProfile: bytes)
            else { continue }
            out[name] = legacy
        }
        return out
    }

    /// `data` without the retired `refusal` and `quit` groups under
    /// `settings`, or nil when it carries neither. Surgical, so the
    /// file keeps its formatting.
    static func withoutLegacyAppWide(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            rewriting: droppingLegacyAppWide,
            editing: legacyAppWideTextDropped
        )
    }

    /// The tree walk the text edit is checked against.
    private static func droppingLegacyAppWide(
        _ node: Any
    ) -> (Any, Bool) {
        guard var root = node as? [String: Any],
            var settings = root[glassSettingsKey] as? [String: Any]
        else { return (node, false) }
        var changed = false
        for group in [retiredRefusalGroup, retiredQuitGroup]
        where settings[group] != nil {
            settings[group] = nil
            changed = true
        }
        root[glassSettingsKey] = settings
        return (root, changed)
    }

    /// Deletes each retired group from the text; stands down where
    /// a group's key is not unique, leaving the verified fallback.
    private static func legacyAppWideTextDropped(
        _ text: String
    ) -> Data? {
        var out = text
        for group in [retiredRefusalGroup, retiredQuitGroup] {
            let entry = "\"\(group)\"\\s*:\\s*\\{[^{}]*\\}"
            let hits =
                out.components(separatedBy: "\"\(group)\"")
                .count - 1
            guard hits <= 1 else { return nil }
            guard hits == 1 else { continue }
            let removed = [
                entry + "\\s*,\\s*", "\\s*,\\s*" + entry, entry,
            ].lazy.map {
                out.replacingOccurrences(
                    of: $0,
                    with: "",
                    options: .regularExpression
                )
            }.first { $0 != out }
            guard let removed else { return nil }
            out = removed
        }
        return out == text ? nil : out.data(using: .utf8)
    }
}
