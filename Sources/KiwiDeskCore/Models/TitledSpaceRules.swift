import Foundation

/// The titled Space rules (#3341): `app:fragment` keys, read
/// through the float grammar (`AppTitleRule.parse`), each naming the
/// Space a new window of that app whose title contains the
/// fragment opens in. Matching is `WindowTitleMatch`'s
/// case-sensitive substring.
///
/// Among one app's rules the longest fragment wins, and between
/// fragments of equal length the one first alphabetically (owner
/// ruling, 2026-11-15): case-folded, then code-point order as the
/// last tie, so every locale orders alike. `order(of:)` is that
/// evaluation order, which the Settings rows draw.
public struct TitledSpaceRules: Sendable, Equatable {
    /// One rule, keyed as the store keys it.
    public struct Rule: Sendable, Equatable {
        public let key: String
        public let app: String
        public let fragment: String
        public let space: SpaceID
    }

    /// Each app's rules in evaluation order.
    private let byApp: [String: [Rule]]

    /// `rules` as the store holds them; a key without a fragment
    /// or a rule without a Space is skipped.
    public init(_ rules: [String: SpaceID] = [:]) {
        var byApp: [String: [Rule]] = [:]
        for (key, space) in rules where !space.raw.isEmpty {
            let parsed = AppTitleRule.parse(key)
            guard let fragment = parsed.title else { continue }
            byApp[parsed.app, default: []].append(
                Rule(
                    key: AppTitleRule.rule(app: parsed.app, title: fragment),
                    app: parsed.app,
                    fragment: fragment,
                    space: space
                )
            )
        }
        self.byApp = byApp.mapValues { $0.sorted(by: Self.precedes) }
    }

    /// Whether `lhs` is consulted before `rhs`.
    public static func precedes(_ lhs: Rule, _ rhs: Rule) -> Bool {
        precedes(lhs.fragment, rhs.fragment)
    }

    /// The tiebreak on fragments alone: longer first, then
    /// alphabetical, case-folded, then code-point order.
    public static func precedes(_ lhs: String, _ rhs: String) -> Bool {
        if lhs.count != rhs.count { return lhs.count > rhs.count }
        let (left, right) = (lhs.lowercased(), rhs.lowercased())
        if left != right { return left < right }
        return lhs < rhs
    }

    /// The Space the first matching rule names for a window of
    /// `app`, its `AppRef.listKey`, titled `title`; nil where none
    /// matches.
    public func space(app: String?, title: String) -> SpaceID? {
        rule(app: app, title: title)?.space
    }

    /// The first matching rule, in evaluation order.
    public func rule(app: String?, title: String) -> Rule? {
        guard let app = app.map(AppTitleRule.appKey) else { return nil }
        return byApp[app]?.first {
            WindowTitleMatch.matches(title, $0.fragment)
        }
    }

    /// Whether `app` holds any titled Space rule.
    public func hasRule(app: String?) -> Bool {
        guard let app = app.map(AppTitleRule.appKey) else { return false }
        return byApp[app]?.isEmpty == false
    }

    /// `app`'s rules in evaluation order.
    public func order(of app: String) -> [Rule] {
        byApp[AppTitleRule.appKey(app)] ?? []
    }

    /// The rules as the store keys them.
    public var rawRules: [String: SpaceID] {
        var result: [String: SpaceID] = [:]
        for rules in byApp.values {
            for rule in rules { result[rule.key] = rule.space }
        }
        return result
    }
}
