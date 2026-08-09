import KiwiDeskCore

/// The per-setting view of the draft (#678 turn 9): which
/// settings differ between the edited `GuiConfig` and the clean
/// baseline, counted for the Home header's "N unsaved changes"
/// button and grouped by area for its popover. One draft, one
/// diff — the footer's dirty flag and this must never disagree,
/// which `SettingsDraftDiffTests` holds by construction
/// (`total == 0` exactly when the configs are equal).
///
/// The walk mirrors the census's path convention — struct
/// fields as `.name` segments, dictionaries as `[]`, scalars
/// and enums as leaves — which is the convention
/// `SettingKeyModelParityTests` already proves the census's
/// `settings.*` ids share. A changed leaf therefore resolves to
/// its `SettingKey` by longest matching census base; several
/// leaves under one setting (a per-space override dictionary, a
/// master/value pair) count as ONE changed setting. Where a
/// master's leaves are NOT under it — the two border masters
/// write across the model — the prefix cannot see them, so the
/// fan-out is declared in `SettingKey.masterWrites` and folded
/// in below.
struct SettingsDraftDiff {
    /// The distinct settings that differ, resolved to census
    /// keys where the path has an owner.
    var changedSettings: [SettingKey] = []
    /// Changed leaf paths no census base claims. Empty in any
    /// healthy diff — the guard keeps the attribution total, so
    /// a `GuiConfig` field landing outside the map reds a test
    /// instead of silently vanishing from the count.
    var unattributed: [String] = []
    /// Whether the raw `init.lua` text differs from its baseline.
    var luaChanged = false

    /// The button's N: distinct changed settings, plus one for
    /// an edited init.lua (the raw editor is one surface, not a
    /// per-key edit), plus any unattributed stragglers so the
    /// count can never read lower than the dirty flag implies.
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
        // Census declaration order, so the popover lists changes
        // the way the areas list their rows.
        diff.changedSettings = SettingKey.allCases.filter {
            keys.contains($0)
        }
        diff.unattributed = orphans.sorted()
        return diff
    }

    // MARK: - Path → SettingKey attribution

    /// The census's model-path ids — `settings.*` for
    /// `TilingSettings` fields and `config.*` for `GuiConfig`'s
    /// top-level ones — normalized exactly as
    /// `SettingKeyModelParityTests` normalizes the settings half
    /// (synthetic row suffixes stripped, instance brackets
    /// `[space]`/`[app]`/`[n]` → `[]`). Action/readonly/state
    /// ids name no model path and stay out.
    static func censusBases() -> [String: SettingKey] {
        var bases: [String: SettingKey] = [:]
        for key in SettingKey.allCases {
            var id = key.id
            guard
                id.hasPrefix("settings.")
                    || id.hasPrefix("config.")
            else { continue }
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
            // First declaration wins: variants of one setting
            // (auto/value pairs) share a base and must resolve
            // to ONE key, or the count double-books a change.
            if bases[base] == nil { bases[base] = key }
            // A dictionary setting also owns its container's
            // own leaves — the walk's `.count` sentinel and any
            // sibling the bracket form cannot prefix-match.
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
        // a first-wins registration, because the follower's own
        // surfaceless census row claims its own path in the
        // loop above and would book a second change for a
        // value the user set once. Prefix matching cannot do
        // this: these leaves sit outside the master's subtree
        // (`SettingKey.masterWrites`).
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

    /// `settings.gapsOverride[]1.outer.top` →
    /// `settings.gapsOverride[].outer.top`.
    ///
    /// Redundant with `censusBases()`' container-prefix
    /// registration by design, and each is the other's ONLY
    /// backup (guard-prover 2026-08-04: deleting either alone
    /// leaves the suite green through the other) — do not
    /// "simplify" one away on the strength of a green run.
    private static func normalized(_ path: String) -> String {
        var result = ""
        var rest = Substring(path)
        while let open = rest.range(of: "[]") {
            result += rest[..<open.upperBound]
            rest = rest[open.upperBound...]
            // Drop the entry key: everything up to the next
            // path separator.
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

    // MARK: - The walk

    /// Leaf paths → display-agnostic value descriptions. Only
    /// EQUALITY of two walks is consumed; the strings never
    /// reach the screen.
    static func leaves(of config: GuiConfig) -> [String: String] {
        var result: [String: String] = [:]
        walk(config.settings, at: "settings", into: &result)
        let mirror = Mirror(reflecting: config)
        for child in mirror.children {
            guard let name = child.label, name != "settings"
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
            // Dictionary order is unstable, so entries key by
            // THEIR OWN key's description under `[]` — two walks
            // of equal dictionaries then produce equal maps.
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
            // Order matters for arrays (the space list IS its
            // order); sets stringify order-independently via a
            // sorted dump.
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
