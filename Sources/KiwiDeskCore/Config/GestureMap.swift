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
        GestureKey(.wheelX, pan): .family(.walk),
        GestureKey(.swipe2, step): .family(.space),
        GestureKey(.wheel, step): .family(.space),
        GestureKey(.wheelX, step): .family(.space),
    ]

    /// The bound keys once `base` lies over the seeds and `profile`
    /// over that. A refused binding is dropped, since a hand-edited
    /// file reaches what the verb refuses, and so is a click whose
    /// keys a drag holds: one press starts one thing.
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
            out.keys.filter { $0.input == .drag }.map(\.keys)
        )
        return out.filter { key, _ in
            switch key.input {
            case .click: !dragKeys.contains(key.keys)
            default: true
            }
        }
    }
}
