import Foundation

/// `keep_settings` for the app rules (#1685 ▸ Ruling 6c): the rule
/// leaves a change report named, written through the App Rules
/// page's own door, `saveRuleReach`. A new rule lands in the shared
/// base as Settings starts one; a rule the live profile already
/// holds keeps the reach it has. Nothing live moves.
extension KiwiCore {
    /// Whether a leaf is an app or float rule.
    static func isRuleLeaf(_ leaf: TouchedLeaf) -> Bool {
        let root = KeepPointer.path(leaf.id)?.first
        return root == KeepRoot.appRules || root == KeepRoot.floatRules
            || root == KeepRoot.floatAutomatically
    }

    /// Writes `leaves` as `live` holds them. A refusal shows as the
    /// re-judge finding the leaf not stored.
    func keepRules(_ leaves: [TouchedLeaf], live: JSONValue) {
        guard var snapshot = ruleReachSnapshot(),
            let page = profiles.currentName
        else { return }
        var floatEdits: [String: [String: Bool]] = [:]
        for leaf in leaves {
            guard let path = KeepPointer.path(leaf.id) else { continue }
            if path == [KeepRoot.floatAutomatically] {
                let key = RuleReachTable<Bool>.floatAutomaticallyKey
                let value = KeepPointer.value(at: path, in: live)?.boolValue
                snapshot.floatAutomatically.keep(
                    key,
                    value: value,
                    editing: page
                )
                continue
            }
            guard path.count == 2 else { continue }
            let key = path[1]
            let value = KeepPointer.value(at: path, in: live)
            if path[0] == KeepRoot.appRules {
                let space = value?.stringValue.map { SpaceID($0) }
                snapshot.appRules.keep(key, value: space, editing: page)
            } else {
                let app = RuleReachTable<[String]>.app(of: key)
                floatEdits[app, default: [:]][key] = value != nil
            }
        }
        for (app, edits) in floatEdits {
            var rules = Set(snapshot.floatRules.resolved(app, for: page) ?? [])
            for (rule, present) in edits {
                if present { rules.insert(rule) } else { rules.remove(rule) }
            }
            snapshot.floatRules.keep(
                app,
                value: rules.isEmpty ? nil : rules.sorted(),
                editing: page
            )
        }
        do {
            try saveRuleReach(snapshot, refreshingLive: false)
        } catch {
            onLog("keep_settings: rule write failed: \(error)")
            return
        }
        onRulesKept()
    }

    /// The live profile's app and float rules as the files resolve
    /// them — what an open Settings draft takes after a keep.
    public func storedRules() -> (apps: [String: SpaceID], floats: [String])? {
        guard let name = profiles.currentName,
            let profile = try? profiles.read(name: name),
            let base = guiConfigStore.load()
        else { return nil }
        let floats = FloatRules(base.floatRules).rawRules
        return (
            ConfigResolver.resolvedAppRules(
                base: base.appRules,
                profile: profile.appRules
            ),
            profile.floatRules?.resolved(
                onto: floats,
                normalizing: FloatRules.normalizedRule
            ) ?? floats
        )
    }

    /// The profiles following the shared rules `leaves` name: every
    /// readable profile without its own rule for that app.
    func ruleFollowers(of leaves: [TouchedLeaf]) -> [String] {
        guard let snapshot = ruleReachSnapshot() else { return [] }
        var names: Set<String> = []
        for leaf in leaves {
            guard let path = KeepPointer.path(leaf.id) else { continue }
            if path == [KeepRoot.floatAutomatically] {
                let table = snapshot.floatAutomatically
                let key = RuleReachTable<Bool>.floatAutomaticallyKey
                names.formUnion(
                    table.profiles.filter {
                        table.entries[$0]?[key] == nil
                    }
                )
                continue
            }
            guard path.count == 2 else { continue }
            if path[0] == KeepRoot.appRules {
                let table = snapshot.appRules
                names.formUnion(
                    table.profiles.filter {
                        table.entries[$0]?[path[1]] == nil
                    }
                )
            } else {
                let table = snapshot.floatRules
                let app = RuleReachTable<[String]>.app(of: path[1])
                names.formUnion(
                    table.profiles.filter {
                        table.entries[$0]?[app] == nil
                    }
                )
            }
        }
        return names.sorted()
    }
}

extension RuleReachTable {
    /// Writes `value` for `key` from `editing`'s page at the reach
    /// the rule already has, or shared for a new one; a removal
    /// takes the rule from where it reaches.
    mutating func keep(_ key: String, value: Value?, editing: String) {
        let reach: RuleReach =
            resolved(key, for: editing) != nil
            ? reach(of: key, editing: editing) : .shared(joining: [])
        apply(
            key,
            value: value,
            reach: reach,
            removal: reach.isShared ? .everywhere : .here,
            editing: editing
        )
    }
}
