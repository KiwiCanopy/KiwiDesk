import Foundation

/// User-overridable float rules from the Lua config:
/// `float_rules = { "com.apple.finder:Get Info",
/// "com.apple.calculator" }`. The identity segment is the app's
/// bundle identifier. `"id"` floats every window of the app;
/// `"id:Title"` matches a case-sensitive title fragment.
public struct FloatRules: Sendable, Equatable {
    private let rules: [(app: String, title: String?)]

    public init(_ rules: [String] = []) {
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

    /// Rules as normalized for matching and config seeding.
    public var rawRules: [String] {
        rules.map { rule in
            rule.title.map { "\(rule.app):\($0)" } ?? rule.app
        }
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
    }
}

/// App-level bundle identifiers KiwiDesk never manages. Matching
/// is case-insensitive, like LaunchServices and other app rules.
public struct IgnoreRules: Sendable, Equatable {
    private let bundleIDs: Set<String>

    public init(_ bundleIDs: [String] = []) {
        self.bundleIDs = Set(bundleIDs.map { $0.lowercased() })
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
