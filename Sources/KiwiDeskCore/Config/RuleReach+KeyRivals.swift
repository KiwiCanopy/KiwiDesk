import Foundation

/// A shortcut table's actions by layer, profile and combo, built
/// once so a page of rows asks for rivals without a scan of every
/// key per row and profile (#2783). For a profile of the table it
/// answers exactly what `RuleReachTable.rival` answers
/// (`KeyRivalsTests`).
public struct KeyRivals: Equatable, Sendable {
    /// Layer → profile → combo → keys, in `rivals(of:)` order.
    private let keys: [String: [String: [String: [String]]]]

    public init(_ table: RuleReachTable<String>) {
        var keys: [String: [String: [String: [String]]]] = [:]
        for key in table.keyIDs {
            let layer = RuleReachTable<String>.keyParts(key).layer
            for profile in table.profiles {
                guard let combo = table.resolved(key, for: profile)
                else { continue }
                keys[layer, default: [:]][profile, default: [:]][
                    combo,
                    default: []
                ].append(key)
            }
        }
        self.keys = keys
    }

    /// The action `profile` binds to `key`'s combo instead, if any.
    public func rival(of key: String, for profile: String, combo: String)
        -> String?
    {
        let layer = RuleReachTable<String>.keyParts(key).layer
        return keys[layer]?[profile]?[combo]?.first { $0 != key }
    }
}
