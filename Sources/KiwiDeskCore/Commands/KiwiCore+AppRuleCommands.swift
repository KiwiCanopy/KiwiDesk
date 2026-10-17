import Foundation

/// The `app_rule.*` verbs (#1685 ▸ Ruling 6c): read and change the
/// live app→Space and float rules from Lua, the CLI and
/// `kiwidesk mcp`. A change is live only — `keep_settings` or a
/// Settings Save stores it — and a config reload, a profile apply
/// or a rule Save re-resolves it from the files.
extension KiwiCore {
    func appRuleCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "app_rule.list":
            return .ok(appRuleList())
        case "app_rule.set_space":
            guard let app = ruleApp(args) else { return noApp }
            guard let raw = args.dropFirst().first?.stringValue,
                !raw.isEmpty
            else {
                return .fail("expected space id")
            }
            guard state.workspaces[SpaceID(raw)] != nil else {
                return .fail("unknown space: \(raw)")
            }
            state.appRules[app] = SpaceID(raw)
            return .ok()
        case "app_rule.remove_space":
            guard let app = ruleApp(args) else { return noApp }
            guard state.appRules[app] != nil else {
                return .fail("no app rule for \(app)")
            }
            state.appRules[app] = nil
            return .ok()
        case "app_rule.set_float":
            guard let rule = floatRule(args) else { return noApp }
            let live = eventLoop.floatRules.rawRules
            guard !live.contains(rule) else { return .ok() }
            setLiveFloatRules(live + [rule])
            return .ok()
        case "app_rule.remove_float":
            guard let rule = floatRule(args) else { return noApp }
            let live = eventLoop.floatRules.rawRules
            guard live.contains(rule) else {
                return .fail("no float rule \(rule)")
            }
            setLiveFloatRules(live.filter { $0 != rule })
            return .ok()
        default:
            return .fail("unknown command: \(command)")
        }
    }

    /// The live rules as the resolver left them, and who owns the
    /// base they resolve over.
    private func appRuleList() -> JSONValue {
        let floats = eventLoop.floatRules
        return .object([
            "spaces": .object(state.appRules.mapValues { .string($0.raw) }),
            "floats": .array(floats.rawRules.sorted().map(JSONValue.string)),
            "tiles": .array(
                floats.guess.tileRules.sorted().map(JSONValue.string)
            ),
            "ignores": .array(
                eventLoop.ignoreRules.rawRules.sorted().map(JSONValue.string)
            ),
            "float_automatically": .bool(floats.guess.enabled),
            "owner": .string(isGuiManaged ? "gui" : "lua"),
            "profile": profiles.currentName.map { .string($0) } ?? .null,
        ])
    }

    /// One app's live rules, the slice `app_rule.list` holds for
    /// it: `explain_window` and `explain_app` both read this.
    func appRuleFacts(_ bundleID: String?) -> JSONValue {
        guard let app = bundleID?.lowercased() else { return .null }
        let floats = eventLoop.floatRules
        let mine = floats.rules(of: app)
        return .object([
            "space": state.appRules[app].map { .string($0.raw) }
                ?? .null,
            "floats": .array(mine.sorted().map(JSONValue.string)),
            "tile_rule": .bool(floats.guess.tileRules.contains(app)),
            "float_automatically": .bool(floats.guess.enabled),
        ])
    }

    /// Installs `rules` live over the current guess, and re-checks
    /// open windows where this call site may (`setFloatAutomatically`
    /// is the precedent).
    private func setLiveFloatRules(_ rules: [String]) {
        let live = eventLoop.floatRules
        installFloatRules(FloatRules(rules, guess: live.guess))
        if mayReconcileWindowRulesNow { eventLoop.reconcileAll() }
    }

    /// The first argument as a lowercased bundle id; nil when empty
    /// or when it carries a title, which only a float rule takes.
    private func ruleApp(_ args: [JSONValue]) -> String? {
        let app = args.first?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let app, !app.isEmpty, !app.contains(":") else {
            return nil
        }
        return app
    }

    /// `app` or `app:title`, normalized as the resolver stores it.
    private func floatRule(_ args: [JSONValue]) -> String? {
        guard let app = ruleApp(args) else { return nil }
        guard let title = args.dropFirst().first?.stringValue,
            !title.isEmpty
        else { return app }
        return FloatRules.rule(app: app, title: title)
    }

    private var noApp: CommandResponse {
        .fail("expected an app's bundle id")
    }
}
