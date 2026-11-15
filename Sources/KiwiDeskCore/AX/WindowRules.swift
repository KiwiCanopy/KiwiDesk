import Foundation

/// Float rules matching an app's rule key — its bundle id, or its
/// process name where it has none (#3211) — and optional
/// case-sensitive title fragments.
public struct FloatRules: Sendable, Equatable {
    private let rules: [(app: String, title: String?)]
    /// Where detection may float a window on a guess (#2173).
    public let guess: FloatGuess

    public init(_ rules: [String] = [], guess: FloatGuess = FloatGuess()) {
        self.guess = guess
        self.rules = rules.map(AppTitleRule.parse)
    }

    /// Rules as normalized for matching and config seeding.
    public var rawRules: [String] {
        rules.map { AppTitleRule.rule(app: $0.app, title: $0.title) }
    }

    /// `bundleID`'s own rules, spelled as `rawRules` spells them.
    public func rules(of bundleID: String) -> [String] {
        let app = AppTitleRule.appKey(bundleID)
        return rules.filter { $0.app == app }
            .map { AppTitleRule.rule(app: $0.app, title: $0.title) }
    }

    /// Cheap gate before title-change float detection; `app` is
    /// the window's `AppRef.listKey` (#3211).
    public func hasTitleRule(app: String?) -> Bool {
        guard let app = app.map(AppTitleRule.appKey) else { return false }
        return rules.contains { $0.app == app && $0.title != nil }
    }

    /// Whether a rule floats a window of `app`, its
    /// `AppRef.listKey` (#3211), titled `title`.
    public func matches(
        app: String?,
        title: String
    ) -> Bool {
        guard let app = app.map(AppTitleRule.appKey) else { return false }
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
