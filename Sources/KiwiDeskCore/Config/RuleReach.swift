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

    /// Profiles that leave an inherited `key` out — they resolve
    /// nothing while the base holds it.
    public func leftOut(_ key: String) -> [String] {
        guard base[key] != nil else { return [] }
        return profiles.filter { entries[$0]?[key] == .some(nil) }
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
            // An entry equal to the old base READ as following it,
            // so it follows the new one too.
            if let oldBase = base[key] {
                for profile in profiles
                where entries[profile]?[key] == .some(oldBase) {
                    setEntry(key, for: profile, .none)
                }
            }
            setBase(key, value)
            setEntry(key, for: editing, .none)
            for profile in joining { setEntry(key, for: profile, .none) }
        case .listed(let members):
            if wasShared { setBase(key, nil) }
            for profile in profiles {
                let entry = entries[profile]?[key]
                if members.contains(profile) || profile == editing {
                    setEntry(key, for: profile, .some(value))
                } else if (old != nil && entry == .some(old))
                    || (entry == .some(nil) && base[key] == nil)
                {
                    // An unticked member, or a left-out mark with
                    // nothing left to leave out.
                    setEntry(key, for: profile, .none)
                }
            }
        }
    }

    /// A combo written for `key` takes it from `rivals` — keys bound
    /// to the same combo, which the caller names (only a family whose
    /// value is a combo has any). The base's rival leaves the base;
    /// a profile the user `ticked` gives its rival up; a profile that
    /// did not keeps its own rival, which wins on that combo, so it
    /// reads as leaving `key` out.
    mutating func takeOver(
        _ key: String,
        value: Value,
        rivals: [String],
        ticked: Set<String>,
        editing: String
    ) {
        if base[key] == value {
            for rival in rivals where base[rival] == value {
                setBase(rival, nil)
            }
        }
        for profile in profiles
        where profile != editing && resolved(key, for: profile) == value {
            let held = rivals.filter {
                resolved($0, for: profile) == value
            }
            guard !held.isEmpty else { continue }
            if ticked.contains(profile) {
                for rival in held { setEntry(rival, for: profile, .some(nil)) }
            } else {
                setEntry(key, for: profile, .some(nil))
            }
        }
        // A "left out" that was only a rival on the OLD combo ends
        // when the shared combo moves off it: that profile follows
        // again, as its file will read.
        guard base[key] == value else { return }
        for profile in profiles
        where profile != editing && entries[profile]?[key] == .some(nil)
            && !rivals.contains(where: { resolved($0, for: profile) == value })
        {
            setEntry(key, for: profile, .none)
        }
    }

    /// Leaves `left` out of the shared `key`.
    private mutating func leaveOut(_ key: String, _ left: Set<String>) {
        for profile in left { setEntry(key, for: profile, .some(nil)) }
    }

    private mutating func remove(
        _ key: String,
        old: Value?,
        removal: RuleRemoval,
        editing: String
    ) {
        switch removal {
        case .here:
            if base[key] == nil {
                setEntry(key, for: editing, .none)
            } else {
                leaveOut(key, [editing])
            }
        case .everywhere:
            if base[key] == old { setBase(key, nil) }
            // Where another shared value survives, a holder of this
            // one is left out of it rather than handed it.
            var holders: Set<String> = []
            for profile in profiles {
                let entry = entries[profile]?[key]
                if entry == .some(old) {
                    if base[key] == nil {
                        setEntry(key, for: profile, .none)
                    } else {
                        holders.insert(profile)
                    }
                } else if entry == .some(nil) && base[key] == nil {
                    // A left-out mark goes with the rule it left out.
                    setEntry(key, for: profile, .none)
                }
            }
            if !holders.isEmpty { leaveOut(key, holders) }
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
