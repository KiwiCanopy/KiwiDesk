import Foundation

/// Screen pins move from each screen setup to the profile, keyed by
/// screen number (#3647 ▸ Ruling, `NumberedPinMigrationTests`): a
/// set's pin to its k-th stored screen becomes Screen k, an area
/// pin keeping its area, and where two sets pin one Space the first
/// stored set wins. Reaches a profile root and a bundle's
/// `profiles[]`; `gui.json` stores no pins. Gated on the format,
/// since the moved key keeps its name.
extension ConfigMigration {
    /// The formats this step introduced, per shape, spelled as
    /// history.
    static let numberedPinsProfileFormat = 43
    static let numberedPinsBundleFormat = 54
    /// Spelled rather than derived, as a historical step names what
    /// it was written to name.
    static let numberedPinsSetsKey = "monitor_sets"
    static let numberedPinsMapKey = "space_monitor_map"
    static let numberedPinsMonitorsKey = "monitors"

    @Sendable
    static func migratingPinsOntoNumbers(_ data: Data) -> Data? {
        let needle = Data("\"\(numberedPinsSetsKey)\"".utf8)
        return surgicallyApplying(
            data,
            gate: { data in
                data.range(of: needle) != nil
                    && belowNumberedPinsFloor(data)
            },
            rewriting: withNumberedPins,
            editing: { _ in nil }
        )
    }

    private static func belowNumberedPinsFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < numberedPinsBundleFormat
        case .profile: return format < numberedPinsProfileFormat
        case .gui, .palettes, .looks: return false
        }
    }

    /// The root, where it is a profile, and each inline profile.
    static func withNumberedPins(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        var changed = numbered(&root)
        if var profiles = root[barEdgeProfilesKey] as? [[String: Any]] {
            var did = false
            for index in profiles.indices where numbered(&profiles[index]) {
                did = true
            }
            if did {
                root[barEdgeProfilesKey] = profiles
                changed = true
            }
        }
        return (root, changed)
    }

    /// One profile's sets' maps, numbered onto the profile; true
    /// where a set carried one.
    private static func numbered(_ profile: inout [String: Any]) -> Bool {
        guard var sets = profile[numberedPinsSetsKey] as? [[String: Any]]
        else { return false }
        var map: [String: String] = [:]
        var changed = false
        for index in sets.indices {
            guard
                let pins = sets[index].removeValue(
                    forKey: numberedPinsMapKey
                ) as? [String: String]
            else { continue }
            changed = true
            let monitors =
                sets[index][numberedPinsMonitorsKey] as? [String] ?? []
            for (space, pin) in pins.sorted(by: { $0.key < $1.key })
            where map[space] == nil {
                // As written for format 43: the first place holding
                // the screen, never a live helper's reading.
                let key = ScreenAreaKey(parsing: pin)
                if let index = monitors.firstIndex(of: key.fingerprint),
                    let slot = ScreenSlotKey(
                        number: index + 1,
                        areaID: key.areaID
                    )
                {
                    map[space] = slot.description
                }
            }
        }
        guard changed else { return false }
        profile[numberedPinsSetsKey] = sets
        profile[numberedPinsMapKey] = map
        return true
    }
}
