import Foundation

/// The "Shortcuts use" switch over a gesture map (#3444): the
/// keyboard rows' `ShortcutBase.moved` mapping, applied to every key
/// the map resolves. The seeds follow the stored base on their own
/// (`GestureSeeds.seeds(on:)`), so the switch renames the stored
/// keys alone and pins a seed whose new key a row of the user's
/// holds. A profile's override follows the base's moves
/// (`following`), as a keyboard override does.
public enum GestureBaseSwitch {
    /// A key the switch could move and did not: `holder`, a key that
    /// stays, binds its target.
    public struct Kept: Equatable, Sendable {
        public let key: GestureKey
        public let target: GestureKey
        public let holder: GestureKey
    }

    /// One switch's result over a base map.
    public struct Moved: Equatable, Sendable {
        public var map: GestureMap
        /// Each moved key's new key and what the old one resolved to
        /// (nil for a seed the map had turned off).
        public var moves: [GestureKey: Move]
        public var kept: [Kept]
    }

    public struct Move: Equatable, Sendable {
        public let to: GestureKey
        public let action: GestureAction?
    }

    /// `map`, laid over the seeds on `old`, moved onto `new` —
    /// save the keys `staying` names, which keep their keys.
    public static func move(
        _ map: GestureMap,
        from old: ShortcutBase,
        onto new: ShortcutBase,
        staying: (GestureKey) -> Bool = { _ in false }
    ) -> Moved {
        guard old != new else {
            return Moved(map: map, moves: [:], kept: [])
        }
        let oldSeeds = GestureSeeds.seeds(on: old)
        let newSeeds = GestureSeeds.seeds(on: new)
        let keys = Set(oldSeeds.keys).union(map.entries.keys)
        func resolved(_ key: GestureKey) -> GestureAction? {
            map.resolved(key, oldSeeds)
        }
        func target(_ key: GestureKey) -> GestureKey? {
            staying(key) ? nil : ShortcutBase.moved(key, to: new)
        }
        // Every entry is written sparse over the seeds on `new`, so
        // a key a seed no longer holds keeps what it resolved to.
        func entry(_ action: GestureAction?, at key: GestureKey)
            -> GestureEntry?
        {
            if action == newSeeds[key] { return nil }
            if let action { return .bound(action) }
            return newSeeds[key] == nil ? nil : .unbound
        }
        var out = GestureMap()
        for key in keys where target(key) == nil {
            out[key] = entry(resolved(key), at: key)
        }
        var moves: [GestureKey: Move] = [:]
        var kept: [Kept] = []
        for key in keys.sorted() {
            guard let to = target(key) else { continue }
            let action = resolved(key)
            // A key the mapping produces is never moved itself.
            if map.resolved(to, oldSeeds) != nil {
                guard let action else { continue }
                out[key] = entry(action, at: key)
                kept.append(Kept(key: key, target: to, holder: to))
                continue
            }
            moves[key] = Move(to: to, action: action)
            out[to] = entry(action, at: to)
        }
        return Moved(map: out, moves: moves, kept: kept)
    }
}

extension GestureBaseSwitch {
    /// The rows of `resolved` the switch onto `base` would leave
    /// where they are: a key the mapping covers whose target another
    /// row binds — the rows `move` pins, which the Settings list
    /// names.
    public static func kept(
        in resolved: [GestureKey: GestureAction],
        onto base: ShortcutBase
    ) -> [Kept] {
        resolved.keys.sorted().compactMap { key in
            guard let to = ShortcutBase.moved(key, to: base),
                resolved[to] != nil
            else { return nil }
            return Kept(key: key, target: to, holder: to)
        }
    }
}

extension GestureMap {
    /// This profile override after its base moved `moves`, so the
    /// profile resolves as it did (`KeyLayerOverride.following`'s
    /// rule): a tombstone on an old key takes the new one; a base
    /// row this override replaced at its old key is left out at the
    /// new one; and a base row its own row now replaces at the new
    /// key stays on the old one as the profile's own.
    public func following(
        _ moves: [GestureKey: GestureBaseSwitch.Move]
    ) -> GestureMap {
        var out = self
        for (old, move) in moves.sorted(by: { $0.key < $1.key }) {
            let ownNew = entries[move.to] != nil
            switch entries[old] {
            case .unbound?:
                out[old] = nil
                if !ownNew { out[move.to] = .unbound }
            case .bound?:
                if !ownNew, move.action != nil { out[move.to] = .unbound }
            case nil:
                if ownNew, let action = move.action {
                    out[old] = .bound(action)
                }
            }
        }
        return out
    }
}
