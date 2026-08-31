import Foundation

/// Sparse per-profile app→space rule override
/// (#109, `AppRuleOverrideTests`).
public struct AppRuleOverride: Sendable, Equatable {
    /// Sparse app overrides where stored `nil` indicates a tombstone unpin.
    public var rules: [String: SpaceID?]

    public init(rules: [String: SpaceID?] = [:]) {
        self.rules = rules
    }

    /// Whether this override has no diverging app rules.
    public var isEmpty: Bool { rules.isEmpty }

    /// Resolves override onto global base rules (#109).
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

extension AppRuleOverride {
    /// Computes sparse difference from base to edited rules (#109).
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

    /// Canonical lowercase bundle-id map shared across resolve and diff.
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

extension AppRuleOverride: Codable {
    private struct AppKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) { nil }
    }

    /// Decodes dictionary with nulls as tombstones
    /// (`GuiConfig.appRules`, #31).
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

extension ConfigResolver {
    /// Resolves effective app rules from base and profile override
    /// (AGENTS.md §5).
    public static func resolvedAppRules(
        base: [String: SpaceID],
        profile: AppRuleOverride?
    ) -> [String: SpaceID] {
        profile?.resolved(onto: base)
            ?? AppRuleOverride.normalized(base)
    }
}
