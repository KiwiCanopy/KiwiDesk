import KiwiDeskCore

/// Per-setting diff between draft `GuiConfig` and baseline (#678,
/// `SettingsDraftDiffTests`).
struct SettingsDraftDiff {
    /// Distinct settings that differ, resolved to census keys.
    var changedSettings: [SettingKey] = []
    /// Changed leaf paths not claimed by any census base.
    var unattributed: [String] = []
    /// True if raw `init.lua` text differs from baseline.
    var luaChanged = false

    /// Total count of changed settings, Lua edit, and unattributed paths.
    var total: Int {
        changedSettings.count + unattributed.count
            + (luaChanged ? 1 : 0)
    }

    static func between(
        config: GuiConfig,
        cleanConfig: GuiConfig,
        luaSource: String = "",
        cleanLuaSource: String = ""
    ) -> SettingsDraftDiff {
        var diff = SettingsDraftDiff()
        diff.luaChanged = luaSource != cleanLuaSource
        let edited = leaves(of: config)
        let clean = leaves(of: cleanConfig)
        let changedPaths = Set(edited.keys)
            .union(clean.keys)
            .filter { edited[$0] != clean[$0] }
        guard !changedPaths.isEmpty else { return diff }

        let bases = censusBases()
        var keys: Set<SettingKey> = []
        var orphans: Set<String> = []
        for path in changedPaths {
            if let key = resolve(path, in: bases) {
                keys.insert(key)
            } else {
                orphans.insert(path)
            }
        }
        diff.changedSettings = SettingKey.allCases.filter {
            keys.contains($0)
        }
        diff.unattributed = orphans.sorted()
        return diff
    }

    /// True if census id names a model path (`SettingsValueReadoutTests`).
    static func namesModelPath(_ id: String) -> Bool {
        id.hasPrefix("settings.") || id.hasPrefix("config.")
    }

    /// Normalized census model-path bases (`SettingKeyModelParityTests`).
    static func censusBases() -> [String: SettingKey] {
        var bases: [String: SettingKey] = [:]
        for key in SettingKey.allCases {
            var id = key.id
            guard namesModelPath(id) else { continue }
            for suffix in [
                " (auto)", " (unit)", " (value)", " (master)",
            ] where id.hasSuffix(suffix) {
                id.removeLast(suffix.count)
            }
            var base = id
            for instance in ["[space]", "[app]", "[n]"] {
                base = base.replacingOccurrences(
                    of: instance,
                    with: "[]"
                )
            }
            if bases[base] == nil { bases[base] = key }
            if let bracket = base.range(of: "[]") {
                let container = String(
                    base[..<bracket.lowerBound]
                )
                if bases[container] == nil {
                    bases[container] = key
                }
            }
        }
        // A master's followers have no row of their own, so the
        // master owns their leaves outright — an OVERRIDE, not
        // first-wins: the follower's surfaceless census row claims
        // its own path above and would book a second change for a
        // value the user set once.
        for (key, paths) in SettingKey.masterWrites {
            for path in paths { bases[path] = key }
        }
        return bases
    }

    /// Longest-prefix match: a leaf inside a struct-valued
    /// setting (`settings.gapsOverride[].outer.top`) belongs to
    /// the setting whose base owns the longest prefix of it.
    /// The walk keys dictionary entries as `[]<key>`; the
    /// census declares the instance slot bare, so the entry
    /// text is dropped before matching.
    static func resolve(
        _ path: String,
        in bases: [String: SettingKey]
    ) -> SettingKey? {
        var probe = normalized(path)
        while true {
            if let key = bases[probe] { return key }
            guard
                let cut = probe.lastIndex(where: {
                    $0 == "." || $0 == "["
                })
            else { return nil }
            probe = String(probe[..<cut])
        }
    }

    /// Normalizes path keys by replacing instance identifiers
    /// with `[]`. Redundant with `censusBases()`' container-prefix
    /// registration BY DESIGN — each is the other's only backup
    /// (guard-prover 2026-08-04: deleting either alone leaves the
    /// suite green through the other). Do not "simplify" one away
    /// on the strength of a green run.
    private static func normalized(_ path: String) -> String {
        var result = ""
        var rest = Substring(path)
        while let open = rest.range(of: "[]") {
            result += rest[..<open.upperBound]
            rest = rest[open.upperBound...]
            if let next = rest.firstIndex(where: {
                $0 == "." || $0 == "["
            }) {
                rest = rest[next...]
            } else {
                rest = ""
            }
        }
        return result + rest
    }

    /// Leaf paths mapped to value descriptions for comparison.
    static func leaves(of config: GuiConfig) -> [String: String] {
        var result: [String: String] = [:]
        walk(config.settings, at: "settings", into: &result)
        let mirror = Mirror(reflecting: config)
        for child in mirror.children {
            guard let name = child.label,
                name != "settings", name != "format"
            else { continue }
            walk(
                child.value,
                at: "config.\(name)",
                into: &result
            )
        }
        return result
    }

    private static func walk(
        _ value: Any,
        at path: String,
        into result: inout [String: String]
    ) {
        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .optional:
            if let child = mirror.children.first {
                walk(child.value, at: path, into: &result)
            } else {
                result[path] = "nil"
            }
        case .dictionary:
            for entry in mirror.children {
                let pair = Mirror(reflecting: entry.value)
                    .children.map(\.value)
                guard pair.count == 2 else { continue }
                walk(
                    pair[1],
                    at: path + "[]\(pair[0])",
                    into: &result
                )
            }
            result[path + ".count"] =
                String(mirror.children.count)
        case .struct:
            for child in mirror.children {
                guard let name = child.label else { continue }
                walk(
                    child.value,
                    at: "\(path).\(name)",
                    into: &result
                )
            }
        case .collection, .set:
            if mirror.displayStyle == .set {
                let parts = mirror.children
                    .map { String(describing: $0.value) }
                    .sorted()
                result[path] = parts.joined(separator: ",")
            } else {
                for (index, child) in mirror.children
                    .enumerated()
                {
                    walk(
                        child.value,
                        at: path + "[]\(index)",
                        into: &result
                    )
                }
                result[path + ".count"] =
                    String(mirror.children.count)
            }
        default:
            result[path] = String(describing: value)
        }
    }
}
