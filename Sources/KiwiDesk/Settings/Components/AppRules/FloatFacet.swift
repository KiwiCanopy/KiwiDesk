import KiwiDeskCore

/// Float facet parsing and filtering helper matching `FloatRules`.
///
/// The colon is the pattern marker, as the engine reads it: a
/// bundle identifier cannot contain one, so `app` floats every
/// window and `app:fragment` floats the windows whose title
/// contains that fragment. A rule's app
/// is keyed through `AppTitleRule.app(of:)`, the engine's own
/// case-folded key (#2345).
enum FloatFacet: Equatable {
    case never
    case all
    case titled

    /// Whether a float rule matches by title rather than floating
    /// every window, read through the engine's own
    /// `AppTitleRule.parse` (#2345). The one spelling of the marker
    /// test (architect review, 2026-09-22).
    static func isTitled(_ rule: String) -> Bool {
        AppTitleRule.title(of: rule) != nil
    }

    /// The app a float rule names, as the engine keys it.
    static func appSegment(of rule: String) -> String {
        AppTitleRule.app(of: rule)
    }

    static func current(
        _ rules: [String],
        app: String
    ) -> FloatFacet {
        var sawTitled = false
        for rule in Self.rules(rules, app: app) {
            if !isTitled(rule) { return .all }
            sawTitled = true
        }
        return sawTitled ? .titled : .never
    }

    static func patterns(
        _ rules: [String],
        app: String
    ) -> [String] {
        Self.rules(rules, app: app).compactMap(AppTitleRule.title(of:))
    }

    /// `rules` with `app`'s title patterns set to `patterns`: a
    /// removed pattern's rule goes, a new one's is appended, the
    /// rest keep their order, and the bare rule goes with any write
    /// — a pattern now picks the app's windows (#1022).
    static func settingPatterns(
        _ patterns: [String],
        of app: String,
        in rules: [String]
    ) -> [String] {
        let app = AppTitleRule.appKey(app)
        let old = Self.patterns(rules, app: app)
        let dropped = Set(old.filter { !patterns.contains($0) })
        var kept = rules.filter { rule in
            let parsed = AppTitleRule.parse(rule)
            guard parsed.app == app else { return true }
            return parsed.title.map { !dropped.contains($0) } ?? false
        }
        for pattern in patterns where !old.contains(pattern) {
            kept.append(AppTitleRule.rule(app: app, title: pattern))
        }
        return kept
    }

    /// `app`'s own rules, in stored order and spelling.
    static func rules(_ rules: [String], app: String) -> [String] {
        let app = AppTitleRule.appKey(app)
        return rules.filter { appSegment(of: $0) == app }
    }

    /// `rules` without any of `app`'s.
    static func removingRules(
        of app: String,
        from rules: [String]
    ) -> [String] {
        let app = AppTitleRule.appKey(app)
        return rules.filter { appSegment(of: $0) != app }
    }
}
