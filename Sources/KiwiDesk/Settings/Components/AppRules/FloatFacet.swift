import KiwiDeskCore

/// Float facet parsing and filtering helper matching `FloatRules`.
///
/// The colon is the pattern marker, as the engine reads it: a
/// bundle identifier cannot contain one, so `app` floats every
/// window and `app:fragment` floats the windows whose title
/// contains that fragment. `AppRuleTitleOffer` reads the same
/// marker to decide whether the titled choice is offered, and
/// `AppRuleTitleOfferTests` pins the two agreeing.
enum FloatFacet: Equatable {
    case never
    case all
    case titled

    /// Whether a float rule matches by title rather than floating
    /// every window. The one spelling of the marker test, so
    /// `AppRuleTitleOffer` cannot read the colon differently from
    /// `current(_:app:)` (architect review, 2026-09-22).
    static func isTitled(_ rule: String) -> Bool {
        rule.contains(":")
    }

    /// A float rule's app segment, case-folded as `FloatRules`
    /// keys it, so a hand-written `Com.Apple.Notes` lists against
    /// the app the engine floats (#2345).
    static func appSegment(of rule: String) -> String {
        let parts = FloatRules.normalizedRule(rule)
            .split(separator: ":", maxSplits: 1)
        return parts.first.map(String.init) ?? ""
    }

    static func current(
        _ rules: [String],
        app: String
    ) -> FloatFacet {
        let app = app.lowercased()
        var sawTitled = false
        for rule in rules where appSegment(of: rule) == app {
            if !isTitled(rule) { return .all }
            sawTitled = true
        }
        return sawTitled ? .titled : .never
    }

    static func patterns(
        _ rules: [String],
        app: String
    ) -> [String] {
        let app = app.lowercased()
        return rules.compactMap { rule in
            let parts = rule.split(
                separator: ":",
                maxSplits: 1
            )
            guard parts.count == 2,
                String(parts[0]).lowercased() == app
            else { return nil }
            return String(parts[1])
        }
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
        let app = app.lowercased()
        let old = Self.patterns(rules, app: app)
        let dropped = Set(old.filter { !patterns.contains($0) })
        var kept = rules.filter { rule in
            let rule = FloatRules.normalizedRule(rule)
            return rule != app
                && !dropped.contains { rule == "\(app):\($0)" }
        }
        for pattern in patterns where !old.contains(pattern) {
            kept.append("\(app):\(pattern)")
        }
        return kept
    }

    static func rules(_ rules: [String], app: String) -> [String] {
        let app = app.lowercased()
        return rules.filter { appSegment(of: $0) == app }
    }
}
