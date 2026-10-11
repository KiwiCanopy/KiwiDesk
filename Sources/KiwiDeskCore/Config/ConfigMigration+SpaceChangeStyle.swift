import Foundation

/// Crosses a stored `animations.on_space_change` onto
/// `animations.space_change` once (#2143,
/// `SpaceChangeStyleMigrationTests`): `true` becomes `"cue"` — the
/// encoder writes `animations` whole, so a `true` is almost always
/// the default, #1931's reasoning — and `false` becomes
/// `"instant"`, the slide-off path it named. Reaches a profile
/// root's `settings` and a bundle root's `profiles[].settings` by
/// PATH, as #1931's step does; `gui.json` carries no `settings`.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let spaceChangeStyleKey = "space_change"
    /// The formats this step introduced, a profile's and a
    /// bundle's.
    static let spaceChangeStyleProfileFormat = 20
    static let spaceChangeStyleBundleFormat = 25

    @Sendable
    static func migratingSpaceChangeStyle(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: spaceChangeStyleProfileFormat,
                bundle: spaceChangeStyleBundleFormat
            )
        else { return nil }
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(spaceChangeLeafKey)\"".utf8))
                    != nil
            },
            rewriting: withSpaceChangeStyle,
            editing: surgicallyCrossedSpaceChange
        )
    }

    /// The two paths: the root's own `settings`, and each inline
    /// profile's under `profiles`.
    static func withSpaceChangeStyle(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        if let settings = root[glassSettingsKey] as? [String: Any],
            let crossed = settingsWithSpaceChangeStyle(settings)
        {
            root[glassSettingsKey] = crossed
            changed = true
        }
        if var profiles = root[glassProfilesKey] as? [[String: Any]] {
            var did = false
            for (index, profile) in profiles.enumerated() {
                guard
                    let settings = profile[glassSettingsKey]
                        as? [String: Any],
                    let crossed = settingsWithSpaceChangeStyle(settings)
                else { continue }
                profiles[index][glassSettingsKey] = crossed
                did = true
            }
            if did {
                root[glassProfilesKey] = profiles
                changed = true
            }
        }
        return (root, changed)
    }

    /// One `TilingSettings` object with its group crossed, or nil
    /// where the group carries no `on_space_change`.
    static func settingsWithSpaceChangeStyle(
        _ settings: [String: Any]
    ) -> [String: Any]? {
        guard
            var group = settings[spaceChangeGroupKey] as? [String: Any],
            let on = group[spaceChangeLeafKey] as? Bool
        else { return nil }
        group[spaceChangeLeafKey] = nil
        group[spaceChangeStyleKey] = spaceChangeStyle(on: on)
        var out = settings
        out[spaceChangeGroupKey] = group
        return out
    }

    static func spaceChangeStyle(on: Bool) -> String {
        (on ? SpaceChangeStyle.cue : .instant).rawValue
    }

    /// The textual edit: each `"on_space_change": <bool>` becomes
    /// `"space_change": "<style>"` where it stands — by KEY, safe
    /// while `TilingSettings` alone declares the group
    /// (`ConfigMigrationGlassRoutingTests` ▸ the `animations`
    /// declarers).
    private static func surgicallyCrossedSpaceChange(
        _ text: String
    ) -> Data? {
        guard
            let regex = try? NSRegularExpression(
                pattern: "\"\(spaceChangeLeafKey)\"(\\s*:\\s*)(true|false)"
            )
        else { return nil }
        var out = text
        let whole = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: whole).reversed() {
            guard let range = Range(match.range, in: out),
                let colon = Range(match.range(at: 1), in: out),
                let value = Range(match.range(at: 2), in: out)
            else { continue }
            let style = spaceChangeStyle(on: out[value] == "true")
            out.replaceSubrange(
                range,
                with: "\"\(spaceChangeStyleKey)\"\(out[colon])\"\(style)\""
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }
}
