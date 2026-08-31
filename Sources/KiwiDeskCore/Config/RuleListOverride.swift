import Foundation

/// Sparse override for a list of normalized string rules.
public struct RuleListOverride: Sendable, Equatable {
    public var rules: [String: Bool?]

    public init(rules: [String: Bool?] = [:]) {
        var sanitized: [String: Bool?] = [:]
        for (rule, value) in rules
        where !rule.isEmpty && value != false {
            sanitized.updateValue(value, forKey: rule)
        }
        self.rules = sanitized
    }

    /// True when no meaningful addition or tombstone is stored.
    public var isEmpty: Bool {
        !rules.contains {
            !$0.key.isEmpty && $0.value != false
        }
    }

    /// Applies sparse override to base rule list with normalized sorting.
    public func resolved(
        onto base: [String],
        normalizing: (String) -> String
    ) -> [String] {
        let normalizedBase = Self.normalizedUnique(
            base,
            normalizing: normalizing
        )
        let actions = normalizedActions(
            normalizing: normalizing
        )
        var result = normalizedBase.filter {
            actions[$0] != false
        }
        var present = Set(result)
        let additions = actions.compactMap { rule, add in
            add && !present.contains(rule) ? rule : nil
        }.sorted()
        for rule in additions {
            result.append(rule)
            present.insert(rule)
        }
        return result
    }

    /// Builds sparse override producing `edited` from `base`.
    public static func diff(
        base: [String],
        edited: [String],
        normalizing: (String) -> String
    ) -> RuleListOverride? {
        let normalizedBase = normalizedUnique(
            base,
            normalizing: normalizing
        )
        let normalizedEdited = normalizedUnique(
            edited,
            normalizing: normalizing
        )
        let baseSet = Set(normalizedBase)
        let editedSet = Set(normalizedEdited)
        var rules: [String: Bool?] = [:]
        for rule in normalizedBase
        where !editedSet.contains(rule) {
            rules.updateValue(nil, forKey: rule)
        }
        for rule in normalizedEdited
        where !baseSet.contains(rule) {
            rules[rule] = true
        }
        let override = RuleListOverride(rules: rules)
        return override.isEmpty ? nil : override
    }
}

extension RuleListOverride {
    private static func normalizedUnique(
        _ rules: [String],
        normalizing: (String) -> String
    ) -> [String] {
        var seen: Set<String> = []
        return rules.compactMap { rule in
            let normalized = normalizing(rule)
            guard !normalized.isEmpty else { return nil }
            return seen.insert(normalized).inserted
                ? normalized
                : nil
        }
    }

    private func normalizedActions(
        normalizing: (String) -> String
    ) -> [String: Bool] {
        var actions: [String: Bool] = [:]
        for (rawRule, value) in rules {
            guard value != false else { continue }
            let rule = normalizing(rawRule)
            guard !rule.isEmpty else { continue }
            if value == nil || actions[rule] == nil {
                actions[rule] = value == true
            }
        }
        return actions
    }
}

extension RuleListOverride: Codable {
    private struct RuleKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RuleKey.self)
        var rules: [String: Bool?] = [:]
        for key in container.allKeys where !key.stringValue.isEmpty {
            if try container.decodeNil(forKey: key) {
                rules.updateValue(nil, forKey: key.stringValue)
            } else if try container.decode(Bool.self, forKey: key) {
                rules[key.stringValue] = true
            }
        }
        self.init(rules: rules)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RuleKey.self)
        for (rule, value) in rules
        where !rule.isEmpty && value != false {
            guard let key = RuleKey(stringValue: rule) else {
                continue
            }
            if value == true {
                try container.encode(true, forKey: key)
            } else {
                try container.encodeNil(forKey: key)
            }
        }
    }
}
