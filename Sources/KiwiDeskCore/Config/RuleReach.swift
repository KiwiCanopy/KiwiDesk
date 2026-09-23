import Foundation

/// Which profiles a rule reaches (#1393): the shared rule every
/// profile inherits, or an explicit list of profiles.
public enum RuleReach: Hashable, Sendable {
    /// The shared base rule. `joining` names the profiles whose
    /// own entry the save drops so they follow it.
    case shared(joining: Set<String>)
    /// Exactly these profiles, each holding its own entry.
    case listed(Set<String>)

    public var isShared: Bool {
        if case .shared = self { return true }
        return false
    }
}

/// What removing a rule from the edited profile takes with it.
public enum RuleRemoval: Hashable, Sendable {
    /// The edited profile alone; the others keep theirs.
    case here
    /// Every profile holding this rule's value, and the base.
    case everywhere
}

/// One rule family across the shared base and every profile's
/// sparse override, keyed by the rule's subject (an app).
///
/// `entries[profile][key]` is that profile's own value, or `nil`
/// when it leaves an inherited rule out; an absent key follows
/// the base. Pure: built from the stored files, edited, and
/// re-encoded by the family adapters (`RuleReach+Families`).
public struct RuleReachTable<Value: Hashable & Sendable>: Equatable,
    Sendable
{
    public var base: [String: Value]
    public var entries: [String: [String: Value?]]
    /// Every profile, in listing order.
    public let profiles: [String]
    /// Keys a change touched — the only ones re-encoded.
    public private(set) var touched: [String: Set<String>] = [:]
    /// Whether the base was touched at all.
    public private(set) var baseTouched: Set<String> = []

    public init(
        base: [String: Value],
        entries: [String: [String: Value?]],
        profiles: [String]
    ) {
        self.base = base
        self.entries = entries
        self.profiles = profiles
    }

    /// The value `profile` resolves for `key`; nil when none.
    public func resolved(_ key: String, for profile: String) -> Value? {
        if let entry = entries[profile]?[key] { return entry }
        return base[key]
    }

    /// Every rule `profile` resolves.
    public func resolved(for profile: String) -> [String: Value] {
        var result = base
        for (key, entry) in entries[profile] ?? [:] {
            result[key] = entry
        }
        return result
    }

    /// Whether `profile` inherits `key` from the base.
    public func follows(_ key: String, _ profile: String) -> Bool {
        guard let base = base[key] else { return false }
        guard let entry = entries[profile]?[key] else { return true }
        return entry == base
    }

    /// The reach a stored rule has from `editing`'s page: shared
    /// when it follows the base, otherwise the profiles that
    /// resolve the same value.
    public func reach(of key: String, editing: String) -> RuleReach {
        if follows(key, editing) { return .shared(joining: []) }
        let value = resolved(key, for: editing)
        return .listed(
            Set(profiles.filter { resolved(key, for: $0) == value })
                .union([editing])
        )
    }

    /// Profiles other than `editing` that resolve a DIFFERENT
    /// value for `key` — the ⚠ on the row.
    public func differing(_ key: String, editing: String) -> [String] {
        let value = resolved(key, for: editing)
        return profiles.filter {
            guard $0 != editing, let other = resolved(key, for: $0)
            else { return false }
            return other != value
        }
    }

    /// Writes `value` for `key` from `editing`'s page at `reach`,
    /// or removes it (`value == nil`) per `removal`.
    public mutating func apply(
        _ key: String,
        value: Value?,
        reach: RuleReach,
        removal: RuleRemoval = .everywhere,
        editing: String
    ) {
        let wasShared = follows(key, editing)
        let old = resolved(key, for: editing)
        guard let value else {
            remove(key, old: old, removal: removal, editing: editing)
            return
        }
        switch reach {
        case .shared(let joining):
            setBase(key, value)
            setEntry(key, for: editing, .none)
            for profile in joining { setEntry(key, for: profile, .none) }
        case .listed(let members):
            if wasShared { setBase(key, nil) }
            for profile in profiles {
                let entry = entries[profile]?[key]
                if members.contains(profile) || profile == editing {
                    setEntry(key, for: profile, .some(value))
                } else if entry == .some(old)
                    || (entry == .some(nil) && base[key] == nil)
                {
                    // An unticked member, or a left-out mark with
                    // nothing left to leave out.
                    setEntry(key, for: profile, .none)
                }
            }
        }
    }

    private mutating func remove(
        _ key: String,
        old: Value?,
        removal: RuleRemoval,
        editing: String
    ) {
        switch removal {
        case .here:
            setEntry(
                key,
                for: editing,
                base[key] == nil ? .none : .some(nil)
            )
        case .everywhere:
            if base[key] == old { setBase(key, nil) }
            // Where another shared value survives, a holder of this
            // one is left out of it rather than handed it.
            let drop: Value?? = base[key] == nil ? .none : .some(nil)
            for profile in profiles {
                let entry = entries[profile]?[key]
                if entry == .some(old) {
                    setEntry(key, for: profile, drop)
                } else if entry == .some(nil) && base[key] == nil {
                    // A left-out mark goes with the rule it left out.
                    setEntry(key, for: profile, .none)
                }
            }
        }
    }

    /// `.none` drops the entry (follow the base); `.some(nil)`
    /// leaves the rule out; `.some(v)` is the profile's own.
    private mutating func setEntry(
        _ key: String,
        for profile: String,
        _ entry: Value??
    ) {
        guard entries[profile]?[key] != entry else { return }
        switch entry {
        case .none: entries[profile]?.removeValue(forKey: key)
        case .some(let value):
            entries[profile, default: [:]].updateValue(
                value,
                forKey: key
            )
        }
        touched[profile, default: []].insert(key)
    }

    private mutating func setBase(_ key: String, _ value: Value?) {
        guard base[key] != value else { return }
        base[key] = value
        baseTouched.insert(key)
    }
}
