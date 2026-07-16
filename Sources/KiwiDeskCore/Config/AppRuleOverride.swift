import Foundation

// MARK: - AppRuleOverride

/// Sparse per-profile app→space rule override (#109). nil
/// (absent) inherits the global `app_rules` base entirely;
/// present, it shadows the base per app: an app the override
/// mentions takes its space, apps it does not mention survive
/// unchanged. Unlike `KeyModeOverride`, a TOMBSTONE exists — a
/// present-but-null entry un-pins an app the base pins, so a
/// profile can add, change, or remove a base rule.
///
/// Bespoke, templated on `KeyModeOverride`'s seam — NOT a
/// generic sparse-override primitive (AGENTS.md §5,
/// `.claude/rules/parity-tests.md`): keyed flat-map merge, so
/// no reflection parity net applies; guarded by a round-trip +
/// resolve + diff-inverse test in `AppRuleOverrideTests`.
public struct AppRuleOverride: Sendable, Equatable {
    /// Sparse: only apps that diverge from the base. A stored
    /// nil is the tombstone (un-pin this app in this profile).
    public var rules: [String: SpaceID?]

    public init(rules: [String: SpaceID?] = [:]) {
        self.rules = rules
    }

    /// True when no app diverges — a fully-inherited profile
    /// needs no stored override (drives sparse encoding).
    public var isEmpty: Bool { rules.isEmpty }

    /// Resolves this override onto `base`, producing the
    /// effective app→space map. Returns `base` unchanged when
    /// empty.
    ///
    /// Merge rule: per-app, override wins — a named space
    /// replaces (or adds) the app's pin, a tombstone removes
    /// it. Base apps the override does not mention survive.
    public func resolved(
        onto base: [String: SpaceID]
    ) -> [String: SpaceID] {
        var result = Self.normalized(base)
        for (app, target) in normalizedRules {
            if let target {
                result[app] = target
            } else {
                result.removeValue(forKey: app)
            }
        }
        return result
    }
}

// MARK: - Diff (inverse of resolved)

extension AppRuleOverride {
    /// Inverse of `resolved(onto:)`: the sparse override that,
    /// resolved onto `base`, yields `edited`. An app whose pin
    /// equals its base pin is inherited and omitted; a changed
    /// or added pin is included; a base app absent from
    /// `edited` becomes a tombstone (un-pin — deletions ARE
    /// expressible here, unlike `KeyModeOverride`). Returns nil
    /// when nothing diverges — a fully-inherited profile stores
    /// no override (an empty override is never persisted).
    public static func diff(
        base: [String: SpaceID],
        edited: [String: SpaceID]
    ) -> AppRuleOverride? {
        let base = normalized(base)
        let edited = normalized(edited)
        var rules: [String: SpaceID?] = [:]
        for (app, space) in edited where base[app] != space {
            rules[app] = space
        }
        for app in base.keys where edited[app] == nil {
            rules.updateValue(nil, forKey: app)
        }
        let over = AppRuleOverride(rules: rules)
        return over.isEmpty ? nil : over
    }

    /// Canonical bundle-id map shared by resolve, diff, and the
    /// global-base cache. Case collisions are invalid in practice;
    /// sorting makes the fallback deterministic for hand edits.
    public static func normalized(
        _ rules: [String: SpaceID]
    ) -> [String: SpaceID] {
        var result: [String: SpaceID] = [:]
        for (app, target) in rules.sorted(by: {
            $0.key < $1.key
        }) {
            result[app.lowercased()] = target
        }
        return result
    }

    /// A tombstone wins when hand-edited case variants collapse
    /// onto one bundle id; otherwise the sorted fallback is stable.
    private var normalizedRules: [String: SpaceID?] {
        var result: [String: SpaceID?] = [:]
        for (app, target) in rules.sorted(by: {
            $0.key < $1.key
        }) {
            let app = app.lowercased()
            if target == nil {
                result.updateValue(nil, forKey: app)
            } else if result[app] != .some(nil) {
                result.updateValue(target, forKey: app)
            }
        }
        return result
    }
}

// MARK: - Codable

extension AppRuleOverride: Codable {
    private struct AppKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) { nil }
    }

    /// Transparent to the base `app_rules` dict: encode/decode
    /// as a bare JSON object (`{"Mail": "1", "Music": null}`),
    /// matching the `GuiConfig.appRules` shape so both surfaces
    /// share one vocabulary (AGENTS.md §5) — null is the
    /// tombstone. Decoded input is untrusted (hand-edited
    /// profile JSON, #31): an empty app name or an empty space
    /// name is dropped, mirroring `GuiConfig`'s decode-time
    /// sanitization.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: AppKey.self
        )
        var rules: [String: SpaceID?] = [:]
        for key in container.allKeys
        where !key.stringValue.isEmpty {
            if try container.decodeNil(forKey: key) {
                rules.updateValue(
                    nil,
                    forKey: key.stringValue
                )
                continue
            }
            let space = try container.decode(
                SpaceID.self,
                forKey: key
            )
            guard !space.raw.isEmpty else { continue }
            rules.updateValue(space, forKey: key.stringValue)
        }
        self.init(rules: rules)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AppKey.self)
        for (app, target) in rules {
            guard let key = AppKey(stringValue: app) else {
                continue
            }
            if let target {
                try container.encode(target, forKey: key)
            } else {
                try container.encodeNil(forKey: key)
            }
        }
    }
}

// MARK: - ConfigResolver

extension ConfigResolver {
    /// Returns the effective app→space rules: `base` (from
    /// gui.json) when `profile` is nil or empty; the per-app
    /// merge otherwise. Sibling of `resolvedModes` — one
    /// resolver per behavior-override tier (AGENTS.md §5).
    public static func resolvedAppRules(
        base: [String: SpaceID],
        profile: AppRuleOverride?
    ) -> [String: SpaceID] {
        profile?.resolved(onto: base)
            ?? AppRuleOverride.normalized(base)
    }
}
