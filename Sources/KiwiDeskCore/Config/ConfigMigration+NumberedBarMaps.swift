import Foundation

/// The bars' and the pocket's per-screen maps move from each physical
/// screen to the profile's screen numbers (#3647 ▸ lane 3c,
/// `NumberedBarMapMigrationTests`): an entry keyed `fingerprint` or
/// `fingerprint#id` becomes `N` or `N#id`, N the place the first
/// stored set holding that fingerprint gives it (twins the lower). An
/// entry whose fingerprint no set holds is dropped, and where two
/// entries land on one key the first stored set's wins. Reaches a
/// profile root and a bundle's `profiles[]`; `gui.json` stores no
/// `settings`, and a look never holds these paths (`LookKeys`).
/// Gated on the format, since the keys keep their names.
extension ConfigMigration {
    /// The formats this step introduced, per shape, spelled as
    /// history.
    static let numberedBarMapsProfileFormat = 45
    static let numberedBarMapsBundleFormat = 57
    /// The maps' paths under `settings`, spelled rather than
    /// derived, as a historical step names what it was written to.
    static let numberedBarMapPaths: [[String]] = [
        ["space_bar", "edge_override"],
        ["app_bar", "edge_override"],
        ["kiwishelf", "pocket_edge_override"],
        ["space_bar", "visibility_override"],
        ["layout", "monocle", "app_bar", "visibility_override"],
        ["layout", "scroll", "app_bar", "visibility_override"],
    ]

    @Sendable
    static func migratingBarMapsOntoNumbers(_ data: Data) -> Data? {
        let needles = ["edge_override", "visibility_override"]
            .map { Data("\"\($0)\"".utf8) }
        return surgicallyApplying(
            data,
            gate: { data in
                needles.contains { data.range(of: $0) != nil }
                    && belowNumberedBarMapsFloor(data)
            },
            rewriting: withNumberedBarMaps,
            editing: { _ in nil }
        )
    }

    private static func belowNumberedBarMapsFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < numberedBarMapsBundleFormat
        case .profile: return format < numberedBarMapsProfileFormat
        case .gui, .palettes, .looks: return false
        }
    }

    /// The root, where it is a profile, and a bundle's inline
    /// profiles.
    static func withNumberedBarMaps(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        switch shape(of: root) {
        case .profile:
            let changed = numberedBarMaps(&root)
            return (root, changed)
        case .bundle:
            guard
                var profiles = root[numberedSplitsProfilesKey]
                    as? [[String: Any]]
            else { return (root, false) }
            var changed = false
            for index in profiles.indices
            where numberedBarMaps(&profiles[index]) {
                changed = true
            }
            if changed { root[numberedSplitsProfilesKey] = profiles }
            return (root, changed)
        case .gui, .palettes, .looks:
            return (root, false)
        }
    }

    /// Every bar map under one profile's `settings`, rekeyed by its
    /// stored sets; true where one changed.
    private static func numberedBarMaps(
        _ profile: inout [String: Any]
    ) -> Bool {
        guard
            var settings = profile[numberedSplitsSettingsKey]
                as? [String: Any]
        else { return false }
        let sets = (profile[numberedSplitsSetsKey] as? [[String: Any]] ?? [])
            .map { $0[numberedSplitsMonitorsKey] as? [String] ?? [] }
        var changed = false
        for path in numberedBarMapPaths
        where rekey(&settings, at: path[...], sets: sets) {
            changed = true
        }
        if changed { profile[numberedSplitsSettingsKey] = settings }
        return changed
    }

    /// The map at `path` under `node` rekeyed; true where one stood.
    private static func rekey(
        _ node: inout [String: Any],
        at path: ArraySlice<String>,
        sets: [[String]]
    ) -> Bool {
        guard let head = path.first else { return false }
        if path.count == 1 {
            guard let map = node[head] as? [String: Any] else {
                return false
            }
            node[head] = numbered(map, sets: sets)
            return true
        }
        guard var child = node[head] as? [String: Any],
            rekey(&child, at: path.dropFirst(), sets: sets)
        else { return false }
        node[head] = child
        return true
    }

    /// `map`'s entries under the number the first stored set holding
    /// each fingerprint gives it, the sets in order so the first set
    /// wins a key; an entry no set holds is dropped.
    static func numbered(
        _ map: [String: Any],
        sets: [[String]]
    ) -> [String: Any] {
        var out: [String: Any] = [:]
        for (index, order) in sets.enumerated() {
            for key in map.keys.sorted() {
                let area = ScreenAreaKey(parsing: key)
                guard
                    sets.firstIndex(where: {
                        $0.contains(area.fingerprint)
                    }) == index,
                    let place = order.firstIndex(of: area.fingerprint),
                    let slot = ScreenSlotKey(
                        number: place + 1,
                        areaID: area.areaID
                    ),
                    out[slot.description] == nil
                else { continue }
                out[slot.description] = map[key]
            }
        }
        return out
    }
}
