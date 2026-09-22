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

    /// Extracts app segment from float rule string (`FloatRules`).
    static func appSegment(of rule: String) -> String {
        let parts = rule.split(separator: ":", maxSplits: 1)
        return parts.count == 2 ? String(parts[0]) : rule
    }

    static func current(
        _ rules: [String],
        app: String
    ) -> FloatFacet {
        var sawTitled = false
        for rule in rules where appSegment(of: rule) == app {
            if rule == app { return .all }
            sawTitled = true
        }
        return sawTitled ? .titled : .never
    }

    static func patterns(
        _ rules: [String],
        app: String
    ) -> [String] {
        rules.compactMap { rule in
            let parts = rule.split(
                separator: ":",
                maxSplits: 1
            )
            guard parts.count == 2,
                String(parts[0]) == app
            else { return nil }
            return String(parts[1])
        }
    }

    static func rules(_ rules: [String], app: String) -> [String] {
        rules.filter { appSegment(of: $0) == app }
    }
}
