import Foundation

/// One stored binding: an action, or `unbound` — the tombstone that
/// turns a seeded or inherited key off (`null` on the wire).
public enum GestureEntry: Hashable, Sendable {
    case bound(GestureAction)
    case unbound

    public var action: GestureAction? {
        if case .bound(let action) = self { return action }
        return nil
    }
}

/// The sparse binding map (#3199 ruling ▸ Storage): keyed by input
/// and keys, a key it does not name inherits. The same shape stores
/// the global base in `gui.json`, laid over the seeds, and a
/// profile's override, laid over the base.
public struct GestureMap: Hashable, Sendable {
    public var entries: [GestureKey: GestureEntry]

    public init(_ entries: [GestureKey: GestureEntry] = [:]) {
        self.entries = entries
    }

    public var isEmpty: Bool { entries.isEmpty }

    /// This map with `profile`'s entries laid over it: what a
    /// profile resolves, still sparse over the seeds.
    public func overlaid(by profile: GestureMap?) -> GestureMap {
        GestureMap(
            entries.merging(profile?.entries ?? [:]) { _, own in own }
        )
    }

    /// The sparse override that turns `base` into `edited`, both
    /// laid over the seeds; nil where they resolve alike.
    public static func diff(
        base: GestureMap,
        edited: GestureMap
    ) -> GestureMap? {
        var out = GestureMap()
        let keys = Set(base.entries.keys).union(edited.entries.keys)
        for key in keys {
            let new = edited.resolved(key)
            guard base.resolved(key) != new else { continue }
            out[key] = new.map(GestureEntry.bound) ?? .unbound
        }
        return out.isEmpty ? nil : out
    }

    /// What `key` resolves to with this map over the seeds.
    func resolved(_ key: GestureKey) -> GestureAction? {
        guard let entry = entries[key] else {
            return GestureSeeds.seeds[key]
        }
        return entry.action
    }

    public subscript(key: GestureKey) -> GestureEntry? {
        get { entries[key] }
        set { entries[key] = newValue }
    }
}

/// The seeded rows and the one resolve (#3199 ▸ Defaults are real
/// rows, and the lane's reading of them). A key the stored base
/// leaves out follows the seed, so a seed a later release adds
/// reaches an install that never touched that key.
public enum GestureSeeds {
    /// The pan's and the Space step's seeded keys.
    public static let panKeys: ScrollChord = [.control, .option]
    public static let stepKeys: ScrollChord = [.control, .option, .command]
    static var pan: ScrollChord { panKeys }
    static var step: ScrollChord { stepKeys }

    public static let seeds: [GestureKey: GestureAction] = [
        GestureKey(.tap4): .run(
            LuaAction(lua: KiwiHubSide.shortcuts.lua, kind: .navigation)
        ),
        GestureKey(.tap3): .run(
            LuaAction(lua: "KiwiDesk.focus_space_last()", kind: .navigation)
        ),
        GestureKey(.drag, [.control, .command]): .grab(.move),
        GestureKey(.drag, pan): .grab(.resize),
        GestureKey(.swipe2, pan): .family(.focus),
        GestureKey(.wheel, pan): .family(.walk),
        // ⌃⌥ alone on a mouse: the wheel walks, sideways switches
        // Spaces (#3281); the trackpad keeps ⌃⌥⌘ for the step.
        GestureKey(.wheelX, pan): .family(.space),
        GestureKey(.swipe2, step): .family(.space),
    ]

    /// The bound keys once `base` lies over the seeds and `profile`
    /// over that. A refused binding is dropped, since a hand-edited
    /// file reaches what the verb refuses, and so is a click or a
    /// hover_move whose keys a drag holds: one press starts one
    /// thing, and a hover grab on those keys would end at the press.
    public static func resolved(
        base: GestureMap,
        profile: GestureMap?
    ) -> [GestureKey: GestureAction] {
        var out = seeds
        for layer in [base, profile ?? GestureMap()] {
            for (key, entry) in layer.entries {
                out[key] = entry.action
            }
        }
        out = out.filter { $0.value.refusal(on: $0.key) == nil }
        let dragKeys = Set(
            out.keys.filter { $0.input == .drag }.map(\.chord)
        )
        return out.filter { key, _ in
            heldByDrag(key, dragKeys: dragKeys) == nil
        }
    }

    /// The refusal of a click or a hover_move on keys a drag holds.
    static func heldByDrag(
        _ key: GestureKey,
        dragKeys: Set<ScrollChord>
    ) -> GestureRefusal? {
        switch key.input {
        case .click, .hoverMove:
            dragKeys.contains(key.chord) ? .keysHeldByDrag : nil
        default: nil
        }
    }

    /// The verb's question before `key` joins `base`: would a drag
    /// hold a click's or a hover_move's keys, either way round? A
    /// drag bound over a live click or hover_move would silence it.
    public static func shadowRefusal(
        of key: GestureKey,
        base: GestureMap,
        profile: GestureMap?
    ) -> GestureRefusal? {
        let resolved = Self.resolved(base: base, profile: profile)
        if key.input == .drag {
            let shadowed = resolved.keys.contains {
                $0.chord == key.chord
                    && ($0.input == .click || $0.input == .hoverMove)
            }
            return shadowed ? .keysHeldByDrag : nil
        }
        let dragKeys = Set(
            resolved.keys.filter { $0.input == .drag }.map(\.chord)
        )
        return heldByDrag(key, dragKeys: dragKeys)
    }
}
