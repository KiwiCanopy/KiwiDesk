import Foundation

/// Float rules matching bundle IDs and optional case-sensitive
/// title fragments.
public struct FloatRules: Sendable, Equatable {
    private let rules: [(app: String, title: String?)]
    /// Where detection may float a window on a guess (#2173).
    public let guess: FloatGuess

    public init(_ rules: [String] = [], guess: FloatGuess = FloatGuess()) {
        self.guess = guess
        self.rules = rules.map { rule in
            let parts = rule.split(
                separator: ":",
                maxSplits: 1
            )
            guard parts.count == 2 else {
                return (rule.lowercased(), nil)
            }
            return (String(parts[0]).lowercased(), String(parts[1]))
        }
    }

    /// Canonical identity used by profile sparse diffs: bundle
    /// ids compare case-insensitively, while title fragments
    /// keep their case-sensitive matching semantics.
    public static func normalizedRule(_ rule: String) -> String {
        let parts = rule.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return rule.lowercased() }
        return String(parts[0]).lowercased() + ":" + String(parts[1])
    }

    /// Rules as normalized for matching and config seeding.
    public var rawRules: [String] {
        rules.map(Self.spelled)
    }

    /// `bundleID`'s own rules, spelled as `rawRules` spells them.
    public func rules(of bundleID: String) -> [String] {
        let app = bundleID.lowercased()
        return rules.filter { $0.app == app }.map(Self.spelled)
    }

    /// A rule as `app` or `app:title`, the grammar `init` parses.
    private static func spelled(_ rule: (app: String, title: String?))
        -> String
    {
        rule.title.map { "\(rule.app):\($0)" } ?? rule.app
    }

    /// Cheap gate before title-change float detection.
    public func hasTitleRule(bundleID: String?) -> Bool {
        guard let bundleID = bundleID?.lowercased() else {
            return false
        }
        return rules.contains {
            $0.app == bundleID && $0.title != nil
        }
    }

    public func matches(
        bundleID: String?,
        title: String
    ) -> Bool {
        guard let bundleID = bundleID?.lowercased() else {
            return false
        }
        return rules.contains { rule in
            guard rule.app == bundleID else { return false }
            guard let fragment = rule.title else { return true }
            return title.contains(fragment)
        }
    }

    public static func == (a: FloatRules, b: FloatRules) -> Bool {
        a.rules.map(\.app) == b.rules.map(\.app)
            && a.rules.map(\.title) == b.rules.map(\.title)
            && a.guess == b.guess
    }
}

/// App-level bundle identifiers KiwiDesk never manages. Matching
/// is case-insensitive, like LaunchServices and other app rules.
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

    public func matches(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleIDs.contains(bundleID.lowercased())
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

    /// Whether a guess may float `bundleID`'s windows.
    public func applies(to bundleID: String?) -> Bool {
        guard enabled else { return false }
        guard let bundleID else { return true }
        return !tiled.contains(Self.normalizedRule(bundleID))
    }

    /// The Tile rules, normalized for matching and config seeding.
    public var tileRules: [String] { tiled.sorted() }
}
