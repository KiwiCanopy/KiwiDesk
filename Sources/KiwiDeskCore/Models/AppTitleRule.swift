import Foundation

/// Whether a window title matches a rule's fragment: a
/// case-sensitive substring, the one reading App Rules' Float and
/// titled Space rows and a KiwiVision lens member share (#2103
/// ruling 32, #3341).
public enum WindowTitleMatch {
    public static func matches(_ title: String, _ fragment: String) -> Bool {
        title.contains(fragment)
    }
}

/// The `app` / `app:title` grammar every title-scoped app rule is
/// written in — a float rule (#2345) and a titled Space rule
/// (#3341). Every reading of such a rule — the engine's, the
/// profile reach's, the Settings lists' — derives from `parse`, so
/// none can split it differently.
public enum AppTitleRule {
    /// A rule read once: `app`, or `app:title` with a non-empty
    /// title fragment — a rule ending in a bare colon is a bare app
    /// whose name keeps the colon, so it matches no bundle id. The
    /// app is case-folded through `appKey`; the fragment keeps its
    /// case.
    public static func parse(
        _ rule: String
    ) -> (app: String, title: String?) {
        let parts = rule.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return (appKey(rule), nil) }
        return (appKey(String(parts[0])), String(parts[1]))
    }

    /// The app a rule names (`parse`).
    public static func app(of rule: String) -> String {
        parse(rule).app
    }

    /// The title fragment a rule matches, nil for a rule over every
    /// window of its app (`parse`).
    public static func title(of rule: String) -> String? {
        parse(rule).title
    }

    /// A rule spelled from its parts, the grammar `parse` reads.
    public static func rule(app: String, title: String?) -> String {
        title.map { "\(app):\($0)" } ?? app
    }

    /// A bundle id as a rule's app is keyed.
    public static func appKey(_ bundleID: String) -> String {
        bundleID.lowercased()
    }

    /// Canonical identity used by profile sparse diffs: bundle
    /// ids compare case-insensitively, while title fragments
    /// keep their case-sensitive matching semantics.
    @Sendable
    public static func normalizedRule(_ rule: String) -> String {
        let parsed = parse(rule)
        return Self.rule(app: parsed.app, title: parsed.title)
    }
}
