import Foundation

/// Lifts every stored track `limit` by one (#1354,
/// `TrackLimitMigrationTests`): the value used to count NORMAL
/// tracks, with the overflow track beside them, and now counts
/// the tracks on screen, so a file below the floor keeps the
/// layout it drew — a stored 2 showed three tracks and becomes
/// 3. Reaches the global `track` group and every `override`
/// under it, by PATH — `settings.layout.track` under a profile
/// root and under a bundle root's `profiles[]`.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps
    /// naming what it was written to name.
    static let trackGroupKey = "track"
    static let trackLayoutKey = "layout"
    static let trackLimitKey = "limit"
    static let trackOverrideKey = "override"
    static let trackSettingsKey = "settings"
    static let trackProfilesKey = "profiles"

    /// The formats this step introduced — a profile's and a
    /// bundle's — spelled as history: a lifted 3 is the same bytes
    /// as a typed 3, so unlike a rename this step cannot tell it
    /// already ran, and without this gate the NEXT format bump
    /// would lift every file again. A file at or above these
    /// stands down; the shape is told by the bundle's marker.
    static let trackLiftProfileFormat = 5
    static let trackLiftBundleFormat = 7

    @Sendable
    static func migratingTrackLimitCount(_ data: Data) -> Data? {
        guard trackLiftApplies(to: data) else { return nil }
        return surgicallyApplying(
            data,
            gate: {
                $0.range(of: Data("\"\(trackGroupKey)\"".utf8)) != nil
            },
            rewriting: withLiftedTrackLimits,
            editing: surgicallyLiftedTrackLimits
        )
    }

    /// Whether `data`'s stamp is below the format this step
    /// introduced for its shape. An unreadable root stands down.
    static func trackLiftApplies(to data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        let floor =
            root[SetupBundle.shapeMarker] != nil
            ? trackLiftBundleFormat : trackLiftProfileFormat
        return format < floor
    }

    /// The two paths: the root's own `settings`, and each inline
    /// profile's under `profiles`.
    static func withLiftedTrackLimits(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        if let settings = root[trackSettingsKey] as? [String: Any] {
            let (lifted, did) = liftedTrackLimits(settings)
            if did {
                root[trackSettingsKey] = lifted
                changed = true
            }
        }
        if let profiles = root[trackProfilesKey] as? [[String: Any]] {
            var out = profiles
            var did = false
            for (index, profile) in profiles.enumerated() {
                guard
                    let settings = profile[trackSettingsKey]
                        as? [String: Any]
                else { continue }
                let (lifted, changedOne) = liftedTrackLimits(settings)
                guard changedOne else { continue }
                out[index][trackSettingsKey] = lifted
                did = true
            }
            if did {
                root[trackProfilesKey] = out
                changed = true
            }
        }
        return (root, changed)
    }

    /// One `TilingSettings` object: the group's own limit under
    /// `layout.track`, then each override's.
    static func liftedTrackLimits(
        _ settings: [String: Any]
    ) -> ([String: Any], Bool) {
        guard var layout = settings[trackLayoutKey] as? [String: Any],
            var track = layout[trackGroupKey] as? [String: Any]
        else { return (settings, false) }
        var changed = false
        if let limit = track[trackLimitKey] as? Int {
            track[trackLimitKey] = limit + 1
            changed = true
        }
        if var overrides = track[trackOverrideKey] as? [String: Any] {
            for (space, value) in overrides {
                guard var override = value as? [String: Any],
                    let limit = override[trackLimitKey] as? Int
                else { continue }
                override[trackLimitKey] = limit + 1
                overrides[space] = override
                changed = true
            }
            track[trackOverrideKey] = overrides
        }
        guard changed else { return (settings, false) }
        layout[trackGroupKey] = track
        var out = settings
        out[trackLayoutKey] = layout
        return (out, true)
    }

    /// The textual edit: every `"limit": N` in the text lifted by
    /// one — safe while `limit` is spelled by the track group and
    /// its override alone, which `ConfigMigrationGlassRoutingTests`
    /// ▸ the `limit` declarers holds; `surgicallyApplying`
    /// re-parses the result against the walk, so a `limit` the
    /// walk did not lift fails the compare and the walk's own
    /// serialization wins rather than a wrong edit.
    static func surgicallyLiftedTrackLimits(_ text: String) -> Data? {
        guard
            let regex = try? NSRegularExpression(
                pattern: "(\"\(trackLimitKey)\"\\s*:\\s*)(\\d+)"
            )
        else { return nil }
        var out = text
        let whole = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: whole).reversed() {
            guard let digits = Range(match.range(at: 2), in: out),
                let value = Int(out[digits])
            else { return nil }
            out.replaceSubrange(digits, with: String(value + 1))
        }
        return out == text ? nil : out.data(using: .utf8)
    }
}
