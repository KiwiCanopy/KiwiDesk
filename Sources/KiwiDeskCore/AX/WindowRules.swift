import Foundation

/// Whether a window title matches a rule's fragment: a
/// case-sensitive substring, the one reading App Rules' Float rows
/// and a KiwiVision lens member share (#2103 ruling 32).
public enum WindowTitleMatch {
    public static func matches(_ title: String, _ fragment: String) -> Bool {
        title.contains(fragment)
    }
}

/// Float rules matching an app's rule key — its bundle id, or its
/// process name where it has none (#3211) — and optional
/// case-sensitive title fragments.
public struct FloatRules: Sendable, Equatable {
    private let rules: [(app: String, title: String?)]
    /// Where detection may float a window on a guess (#2173).
    public let guess: FloatGuess

    public init(_ rules: [String] = [], guess: FloatGuess = FloatGuess()) {
        self.guess = guess
        self.rules = rules.map(Self.parse)
    }

    /// A float rule's grammar, read once: `app`, or `app:title`
    /// with a non-empty title fragment — a rule ending in a bare
    /// colon is a bare app whose name keeps the colon, so it
    /// matches no bundle id. The app is case-folded through
    /// `appKey`; the fragment keeps its case. Every reading of a
    /// rule — the engine's, the profile reach's, the Float list's
    /// — derives from this, so none can split it differently
    /// (#2345).
    public static func parse(
        _ rule: String
    ) -> (app: String, title: String?) {
        let parts = rule.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return (appKey(rule), nil) }
        return (appKey(String(parts[0])), String(parts[1]))
    }

    /// The app a float rule names (`parse`).
    public static func app(of rule: String) -> String {
        parse(rule).app
    }

    /// The title fragment a float rule matches, nil for a rule
    /// that floats every window of its app (`parse`).
    public static func title(of rule: String) -> String? {
        parse(rule).title
    }

    /// A rule spelled from its parts, the grammar `parse` reads.
    public static func rule(app: String, title: String?) -> String {
        title.map { "\(app):\($0)" } ?? app
    }

    /// A bundle id as a float rule's app is keyed.
    public static func appKey(_ bundleID: String) -> String {
        bundleID.lowercased()
    }

    /// Canonical identity used by profile sparse diffs: bundle
    /// ids compare case-insensitively, while title fragments
    /// keep their case-sensitive matching semantics.
    public static func normalizedRule(_ rule: String) -> String {
        let parsed = parse(rule)
        return Self.rule(app: parsed.app, title: parsed.title)
    }

    /// Rules as normalized for matching and config seeding.
    public var rawRules: [String] {
        rules.map { Self.rule(app: $0.app, title: $0.title) }
    }

    /// `bundleID`'s own rules, spelled as `rawRules` spells them.
    public func rules(of bundleID: String) -> [String] {
        let app = Self.appKey(bundleID)
        return rules.filter { $0.app == app }
            .map { Self.rule(app: $0.app, title: $0.title) }
    }

    /// Cheap gate before title-change float detection; `app` is
    /// the window's `AppRef.listKey` (#3211).
    public func hasTitleRule(app: String?) -> Bool {
        guard let app = app.map(Self.appKey) else { return false }
        return rules.contains { $0.app == app && $0.title != nil }
    }

    /// Whether a rule floats a window of `app`, its
    /// `AppRef.listKey` (#3211), titled `title`.
    public func matches(
        app: String?,
        title: String
    ) -> Bool {
        guard let app = app.map(Self.appKey) else { return false }
        return rules.contains { rule in
            guard rule.app == app else { return false }
            guard let fragment = rule.title else { return true }
            return WindowTitleMatch.matches(title, fragment)
        }
    }

    public static func == (a: FloatRules, b: FloatRules) -> Bool {
        a.rules.map(\.app) == b.rules.map(\.app)
            && a.rules.map(\.title) == b.rules.map(\.title)
            && a.guess == b.guess
    }
}

/// Apps KiwiDesk never manages, each by its rule key — a bundle id,
/// or a process name where the app has none (#3211). Matching is
/// case-insensitive, like LaunchServices and other app rules.
public struct IgnoreRules: Sendable, Equatable {
    private let bundleIDs: Set<String>

    public init(_ bundleIDs: [String] = []) {
        self.bundleIDs = Set(bundleIDs.map { $0.lowercased() })
    }

    /// Canonical identity shared by matching and profile diffs.
    public static func normalizedRule(_ rule: String) -> String {
        rule.lowercased()
    }

    /// Rules normalized for matching and config seeding.
    public var rawRules: [String] {
        bundleIDs.sorted()
    }

    /// Whether a rule names `app`, its `AppRef.listKey` (#3211).
    public func matches(app: String?) -> Bool {
        guard let app else { return false }
        return bundleIDs.contains(app.lowercased())
    }
}

/// Which apps detection may float on a GUESS — a fixed size, no
/// Dock icon — rather than a structure no setting removes (#2173):
/// none while `float_automatically` is off, else every app without
/// a Tile rule (`tile_rules`).
public struct FloatGuess: Sendable, Equatable {
    public var enabled: Bool
    private let tiled: Set<String>

    /// `float_automatically`'s default: the guesses float.
    public static let enabledByDefault = true

    public init(
        enabled: Bool = FloatGuess.enabledByDefault,
        tileRules: [String] = []
    ) {
        self.enabled = enabled
        tiled = Set(tileRules.map(Self.normalizedRule))
    }

    /// Canonical identity shared by matching and profile diffs: a
    /// bundle id, case-insensitive.
    public static func normalizedRule(_ rule: String) -> String {
        rule.lowercased()
    }

    /// Whether a guess may float the windows of `app`, its
    /// `AppRef.listKey` (#3211); an app with no key has no Tile
    /// rule.
    public func applies(toApp app: String?) -> Bool {
        guard enabled else { return false }
        guard let app else { return true }
        return !tiled.contains(Self.normalizedRule(app))
    }

    /// The Tile rules, normalized for matching and config seeding.
    public var tileRules: [String] { tiled.sorted() }
}
