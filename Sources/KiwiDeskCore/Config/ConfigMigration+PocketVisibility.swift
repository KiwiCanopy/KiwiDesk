import Foundation

/// The app-wide `pocket.capacity` retires for each profile's
/// `kiwishelf.pocket_visibility` (#2978 ruling 7). A profile file
/// cannot read `gui.json`, so the files on disk cross by adoption
/// (`KiwiCore.crossPocketVisibility`); a bundle carries both halves
/// and crosses here, in one step.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let pocketCapacityGroup = "pocket"
    static let pocketCapacityKey = "capacity"
    static let pocketVisibilityKey = "pocket_visibility"
    static let pocketVisibilityShelf = "kiwishelf"
    /// The formats this crossing introduced, spelled as history.
    static let pocketVisibilityBundleFormat = 43
    static let pocketVisibilityGuiFormat = 19

    /// What a profile with `settings` crosses to from `capacity`:
    /// One window is Hidden; Several takes the bars' Show where they
    /// agree, a Hidden agreement keeping the handle as Auto, and
    /// mixed bars take Always where the whole mark rested, else Auto.
    static func crossedPocketVisibility(
        capacity: String,
        settings: TilingSettings
    ) -> ShelfVisibility {
        guard capacity == "several" else { return .hidden }
        let bars =
            [settings.spaceBarStyle.visibility]
            + LayoutMode.allCases.compactMap {
                settings.appBarVisibility(in: $0)
            }
        if let first = bars.first, bars.allSatisfy({ $0 == first }) {
            return first == .hidden ? .auto : first
        }
        let restedWhole = LayoutMode.allCases.contains {
            settings.restedWholeBeforeVisibility(in: $0)
        }
        return restedWhole ? .always : .auto
    }

    /// `gui.json`'s retired `pocket.capacity`, nil once crossed. A
    /// file below this crossing's format with no group read as One
    /// window, the old default, so its absence crosses as `one`.
    static func retiredPocketCapacity(in data: Data) -> String? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return nil }
        if let group = root[pocketCapacityGroup] as? [String: Any] {
            return group[pocketCapacityKey] as? String ?? "one"
        }
        let format = root["format"] as? Int ?? 0
        return format < pocketVisibilityGuiFormat ? "one" : nil
    }

    /// `data` with an absent group stated as the `capacity` it read
    /// as, so the debt outlives a restamp while a profile has not
    /// crossed; nil where the file states one already.
    static func statingPocketCapacity(
        _ capacity: String,
        in data: Data
    ) -> Data? {
        guard
            var root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            root[pocketCapacityGroup] == nil
        else { return nil }
        root[pocketCapacityGroup] = [pocketCapacityKey: capacity]
        return try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// Whether a profile's `settings` object already states the
    /// pocket's Show, so the crossing leaves it alone.
    static func statesPocketVisibility(_ settings: [String: Any]) -> Bool {
        let shelf = settings[pocketVisibilityShelf] as? [String: Any]
        return shelf?[pocketVisibilityKey] != nil
    }

    @Sendable
    static func migratingPocketCapacityOntoShelf(_ data: Data) -> Data? {
        guard
            stampBelow(
                data,
                file: 0,
                bundle: pocketVisibilityBundleFormat
            ),
            var root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return nil }
        // An older bundle with no group read as One window, as did
        // one with no config at all, a Lua-owned setup's.
        var config = root["config"] as? [String: Any]
        let group = config?[pocketCapacityGroup] as? [String: Any]
        let capacity = group?[pocketCapacityKey] as? String ?? "one"
        if config != nil {
            config?[pocketCapacityGroup] = nil
            root["config"] = config
        }
        if var profiles = root[barEdgeProfilesKey] as? [[String: Any]] {
            for index in profiles.indices {
                guard
                    var settings = profiles[index][barEdgeSettingsKey]
                        as? [String: Any],
                    !statesPocketVisibility(settings),
                    let decoded = decodedSettings(settings)
                else { continue }
                var shelf =
                    settings[pocketVisibilityShelf] as? [String: Any] ?? [:]
                shelf[pocketVisibilityKey] =
                    crossedPocketVisibility(
                        capacity: capacity,
                        settings: decoded
                    ).rawValue
                settings[pocketVisibilityShelf] = shelf
                profiles[index][barEdgeSettingsKey] = settings
            }
            root[barEdgeProfilesKey] = profiles
        }
        return try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// A profile file's bytes with the pocket's Show stated: one
    /// textual insert into its one shelf object, else a walk.
    static func withPocketVisibility(
        _ value: ShelfVisibility,
        in data: Data
    ) -> Data? {
        let pair = "\"\(pocketVisibilityKey)\":\"\(value.rawValue)\""
        if let text = String(data: data, encoding: .utf8),
            count(of: "\"\(barEdgeSettingsKey)\"", in: text) == 1,
            case .some(.some(let span)) = objectSpan(
                ofKey: pocketVisibilityShelf,
                in: text
            ),
            let range = Range(span, in: text),
            let brace = text[range].firstIndex(of: "{")
        {
            let rest = text[text.index(after: brace)...]
            let empty = rest.drop { $0.isWhitespace }.first == "}"
            var out = text
            out.insert(
                contentsOf: pair + (empty ? "" : ","),
                at: text.index(after: brace)
            )
            return out.data(using: .utf8)
        }
        guard
            var root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            var settings = root[barEdgeSettingsKey] as? [String: Any]
        else { return nil }
        var shelf = settings[pocketVisibilityShelf] as? [String: Any] ?? [:]
        shelf[pocketVisibilityKey] = value.rawValue
        settings[pocketVisibilityShelf] = shelf
        root[barEdgeSettingsKey] = settings
        return try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// A `settings` object as the settings it decodes to.
    static func decodedSettings(_ settings: [String: Any]) -> TilingSettings? {
        guard
            let data = try? JSONSerialization.data(withJSONObject: settings)
        else { return nil }
        return try? JSONDecoder().decode(TilingSettings.self, from: data)
    }
}

extension TilingSettings {
    /// Whether the pocket rested as its whole mark in `mode` before
    /// it had a Show of its own (#2784 ▸ 8): on an edge no bar sits
    /// on, while the more present bar read Always. The crossing's
    /// reading alone (#2978 ruling 7).
    func restedWholeBeforeVisibility(in mode: LayoutMode) -> Bool {
        let app = appBarVisibility(in: mode)
        let onBarEdge = barEdges(
            space: spaceBarStyle.visibility,
            app: app
        ).contains { $0.edge == kiwishelf.pocketEdge }
        guard !onBarEdge else { return false }
        let show = [spaceBarStyle.visibility, app]
            .compactMap { $0 }
            .max { $0.presence < $1.presence }
        return show == .always
    }
}
