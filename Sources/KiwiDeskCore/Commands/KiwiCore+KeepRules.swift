import Foundation

/// `keep_settings` for the app rules and the automatic-float switch
/// (#1685 ▸ Ruling 6c): the rule leaves a change report named,
/// written through the App Rules page's own door, `saveRuleReach`,
/// at the reach that page's encoder would give them —
/// `RuleReachTable.defaultReach` on the loaded profile, so a new rule
/// is shared — and moving nothing live.
extension KiwiCore {
    /// Whether a leaf is a rule leaf, which this door writes.
    static func isRuleLeaf(_ leaf: TouchedLeaf) -> Bool {
        KeepPointer.path(leaf.id).map(isRulePath) ?? false
    }

    static func isRulePath(_ path: [String]) -> Bool {
        let root = path.first
        return root == KeepRoot.appRules || root == KeepRoot.floatRules
            || root == KeepRoot.floatAutomatically
    }

    /// Writes `leaves` as `live` holds them; answers every profile
    /// whose resolved rule the write changed. A refused write shows
    /// as the re-judge finding the leaf not stored.
    func keepRules(_ leaves: [TouchedLeaf], live: JSONValue) -> [String] {
        guard var snapshot = ruleReachSnapshot(),
            let page = profiles.currentName
        else { return [] }
        let before = snapshot
        var appKeys: Set<String> = []
        var floatEdits: [String: [String: Bool]] = [:]
        let autoKey = RuleReachTable<Bool>.floatAutomaticallyKey
        var autoKept = false
        for leaf in leaves {
            guard let path = KeepPointer.path(leaf.id) else { continue }
            let value = KeepPointer.value(at: path, in: live)
            switch (path.first, path.count) {
            case (KeepRoot.floatAutomatically?, 1):
                snapshot.floatAutomatically.keep(
                    autoKey,
                    value: value?.boolValue,
                    editing: page
                )
                autoKept = true
            case (KeepRoot.appRules?, 2):
                appKeys.insert(path[1])
                snapshot.appRules.keep(
                    path[1],
                    value: value?.stringValue.map { SpaceID($0) },
                    editing: page
                )
            case (KeepRoot.floatRules?, 2):
                let app = RuleReachTable<[String]>.app(of: path[1])
                floatEdits[app, default: [:]][path[1]] = value != nil
            default:
                continue
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
            try saveRuleReach(snapshot, origin: .outside)
        } catch {
            onLog("keep_settings: rule write failed: \(error)")
            return []
        }
        var reached = Set(
            snapshot.appRules.profilesChanged(
                from: before.appRules,
                keys: appKeys
            )
        )
        reached.formUnion(
            snapshot.floatRules.profilesChanged(
                from: before.floatRules,
                keys: Set(floatEdits.keys)
            )
        )
        if autoKept {
            reached.formUnion(
                snapshot.floatAutomatically.profilesChanged(
                    from: before.floatAutomatically,
                    keys: [autoKey]
                )
            )
        }
        return reached.sorted()
    }
}

extension RuleReachTable {
    /// Writes `value` for `key` at the page encoder's default reach
    /// on the loaded profile, and a removal everywhere, as a
    /// Settings Save with nothing picked does.
    mutating func keep(_ key: String, value: Value?, editing: String) {
        apply(
            key,
            value: value,
            reach: defaultReach(of: key, editing: editing, isLoaded: true),
            removal: .everywhere,
            editing: editing
        )
    }

    /// Whether a keep of `key` writes the shared base — the
    /// judge's owner, read off the same reach the write takes.
    func keepIsShared(_ key: String, editing: String) -> Bool {
        defaultReach(of: key, editing: editing, isLoaded: true).isShared
    }
}
