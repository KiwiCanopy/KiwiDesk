import Foundation

// The two App Rules families as `RuleReachTable`s (#1393): read
// from the stored base and overrides, and written back touching
// only the keys a change reached — an untouched rule is written
// exactly as it was stored.

extension RuleReachTable where Value == SpaceID {
    /// The app→Space family: keys are lowercased bundle ids.
    public static func appRules(
        base: [String: SpaceID],
        overrides: [(profile: String, override: AppRuleOverride?)]
    ) -> Self {
        var entries: [String: [String: SpaceID?]] = [:]
        for (profile, override) in overrides {
            entries[profile] = override?.normalizedRules ?? [:]
        }
        return Self(
            base: AppRuleOverride.normalized(base),
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// The base app rules: `original` with only the touched keys
    /// replaced, so an untouched rule keeps its stored spelling.
    public func appRuleBase(original: [String: SpaceID]) -> [String: SpaceID] {
        guard !baseTouched.isEmpty else { return original }
        var result = original.filter {
            !baseTouched.contains($0.key.lowercased())
        }
        for key in baseTouched {
            if let value = base[key] { result[key] = value }
        }
        return result
    }

    /// `profile`'s override as the table now holds it; nil when
    /// empty. Only a profile a change touched differs from its file.
    public func appRuleOverride(for profile: String) -> AppRuleOverride? {
        let rules = entries[profile] ?? [:]
        return rules.isEmpty ? nil : AppRuleOverride(rules: rules)
    }
}

extension RuleReachTable where Value == [String] {
    /// The float family, grouped per app: a value is the app's
    /// sorted, normalized rules (`app` and `app:title` patterns).
    public static func floatRules(
        base: [String],
        overrides: [(profile: String, override: RuleListOverride?)]
    ) -> Self {
        let grouped = groupedByApp(base)
        var entries: [String: [String: [String]?]] = [:]
        for (profile, override) in overrides {
            var own: [String: [String]?] = [:]
            let rules = override?.rules ?? [:]
            let apps = Set(
                rules.filter { $0.value != false }.keys.map {
                    app(of: FloatRules.normalizedRule($0))
                }
            )
            for app in apps {
                let subset = rules.filter {
                    Self.app(of: FloatRules.normalizedRule($0.key)) == app
                }
                let inherited = grouped[app] ?? []
                let resolved = RuleListOverride(rules: subset)
                    .resolved(
                        onto: inherited,
                        normalizing: FloatRules.normalizedRule
                    ).sorted()
                if !resolved.isEmpty {
                    own[app] = resolved
                } else if !inherited.isEmpty {
                    own.updateValue(nil, forKey: app)
                }
            }
            entries[profile] = own
        }
        return Self(
            base: grouped,
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// The base float list: `original` with every touched app's
    /// rules replaced by the table's.
    public func floatRuleBase(original: [String]) -> [String] {
        guard !baseTouched.isEmpty else { return original }
        var result = original.filter {
            !baseTouched.contains(
                Self.app(of: FloatRules.normalizedRule($0))
            )
        }
        for app in baseTouched.sorted() {
            result += base[app] ?? []
        }
        return result
    }

    /// `profile`'s override: `original` with each re-encoded
    /// app's entries rebuilt against the NEW base. An app whose
    /// base moved is re-encoded too, since a stored add or
    /// tombstone is relative to the base it was written over.
    public func floatRuleOverride(
        for profile: String,
        original: RuleListOverride?
    ) -> RuleListOverride? {
        let own = entries[profile] ?? [:]
        let apps = (touched[profile] ?? [])
            .union(baseTouched.filter { own[$0] != nil })
        guard !apps.isEmpty else { return original }
        var rules = (original?.rules ?? [:]).filter {
            !apps.contains(Self.app(of: FloatRules.normalizedRule($0.key)))
        }
        for app in apps {
            guard let entry = own[app] else { continue }
            // The list primitive's own encoding, per app.
            let encoded = RuleListOverride.diff(
                base: base[app] ?? [],
                edited: entry ?? [],
                normalizing: FloatRules.normalizedRule
            )
            rules.merge(encoded?.rules ?? [:]) { _, new in new }
        }
        let override = RuleListOverride(rules: rules)
        return override.isEmpty ? nil : override
    }

    /// The app a normalized float rule names.
    public static func app(of rule: String) -> String {
        let parts = rule.split(separator: ":", maxSplits: 1)
        return parts.count == 2 ? String(parts[0]) : rule
    }

    /// A flat rule list as the table's per-app values.
    public static func groupedByApp(_ rules: [String]) -> [String: [String]] {
        var grouped: [String: [String]] = [:]
        for rule in rules {
            let normalized = FloatRules.normalizedRule(rule)
            guard !normalized.isEmpty else { continue }
            grouped[app(of: normalized), default: []].append(normalized)
        }
        return grouped.mapValues { Array(Set($0)).sorted() }
    }
}
