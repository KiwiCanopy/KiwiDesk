import Foundation

/// Screen splits move from each physical screen to the profile's
/// screen numbers, stored as per-mille shares (#3647 ▸ lane 3,
/// `NumberedSplitMigrationTests`): a split keyed by a fingerprint
/// becomes the shares of the number the first stored set holding
/// that fingerprint gives it (twins the lower), its points read
/// against the size the fingerprint carries, so no screen needs to
/// be connected. A fingerprint no set holds, or one with no size, is
/// dropped; where two fingerprints land on one number the first
/// stored set wins. Ids, the next id and names are kept. Reaches a
/// profile root and a bundle's `profiles[]`; `gui.json` stores no
/// `settings`. Gated on the format, since the key keeps its name.
extension ConfigMigration {
    /// The formats this step introduced, per shape, spelled as
    /// history.
    static let numberedSplitsProfileFormat = 44
    static let numberedSplitsBundleFormat = 56
    /// Spelled rather than derived, as a historical step names what
    /// it was written to name.
    static let numberedSplitsKey = "display_areas"
    static let numberedSplitsSettingsKey = "settings"
    static let numberedSplitsProfilesKey = "profiles"
    static let numberedSplitsSetsKey = "monitor_sets"
    static let numberedSplitsMonitorsKey = "monitors"

    @Sendable
    static func migratingSplitsOntoNumbers(_ data: Data) -> Data? {
        let needle = Data("\"\(numberedSplitsKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { data in
                data.range(of: needle) != nil
                    && belowNumberedSplitsFloor(data)
            },
            rewriting: withNumberedSplits,
            editing: { _ in nil }
        )
    }

    private static func belowNumberedSplitsFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < numberedSplitsBundleFormat
        case .profile: return format < numberedSplitsProfileFormat
        case .gui, .palettes, .looks: return false
        }
    }

    /// The root, where it is a profile, and a bundle's inline
    /// profiles.
    static func withNumberedSplits(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = false
        switch shape(of: root) {
        case .profile:
            changed = numberedSplits(&root, sets: sets(of: root))
        case .bundle:
            if var profiles = root[numberedSplitsProfilesKey]
                as? [[String: Any]]
            {
                var did = false
                for index in profiles.indices {
                    let sets = sets(of: profiles[index])
                    if numberedSplits(&profiles[index], sets: sets) {
                        did = true
                    }
                }
                if did {
                    root[numberedSplitsProfilesKey] = profiles
                    changed = true
                }
            }
        case .gui, .palettes, .looks:
            break
        }
        return (root, changed)
    }

    private static func sets(of profile: [String: Any]) -> [[String]] {
        (profile[numberedSplitsSetsKey] as? [[String: Any]] ?? [])
            .map { $0[numberedSplitsMonitorsKey] as? [String] ?? [] }
    }

    /// One `settings.display_areas`, each fingerprint numbered by
    /// its place in the first stored set holding it, the sets taken
    /// in order so the first set wins a number; true where it
    /// carried one.
    private static func numberedSplits(
        _ owner: inout [String: Any],
        sets: [[String]]
    ) -> Bool {
        guard
            var settings = owner[numberedSplitsSettingsKey]
                as? [String: Any],
            let splits = settings[numberedSplitsKey] as? [String: Any]
        else { return false }
        var numbered: [String: Any] = [:]
        for (index, order) in sets.enumerated() {
            for fingerprint in splits.keys.sorted() {
                guard
                    sets.firstIndex(where: { $0.contains(fingerprint) })
                        == index,
                    let place = order.firstIndex(of: fingerprint),
                    numbered[String(place + 1)] == nil,
                    let shares = shares(splits[fingerprint], fingerprint)
                else { continue }
                numbered[String(place + 1)] = shares
            }
        }
        settings[numberedSplitsKey] = numbered
        owner[numberedSplitsSettingsKey] = settings
        return true
    }

    /// One stored split in points as shares of the screen
    /// `fingerprint` names, nil where it is no split or the
    /// fingerprint carries no size.
    private static func shares(
        _ value: Any?,
        _ fingerprint: String
    ) -> Any? {
        guard let value,
            let size = ScreenShares.size(of: fingerprint),
            let bytes = try? JSONSerialization.data(withJSONObject: value),
            let split = try? JSONDecoder().decode(
                ScreenSplit.self,
                from: bytes
            ),
            let encoded = try? JSONEncoder().encode(
                ScreenShares(split, width: size.width, height: size.height)
            )
        else { return nil }
        return try? JSONSerialization.jsonObject(with: encoded)
    }
}
