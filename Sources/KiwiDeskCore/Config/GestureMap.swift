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
    /// laid over the seeds on `shortcutBase`; nil where they
    /// resolve alike.
    public static func diff(
        base: GestureMap,
        edited: GestureMap,
        shortcutBase: ShortcutBase
    ) -> GestureMap? {
        var out = GestureMap()
        let seeds = GestureSeeds.seeds(on: shortcutBase)
        let keys = Set(base.entries.keys).union(edited.entries.keys)
        for key in keys {
            let new = edited.resolved(key, seeds)
            guard base.resolved(key, seeds) != new else { continue }
            out[key] = new.map(GestureEntry.bound) ?? .unbound
        }
        return out.isEmpty ? nil : out
    }

    /// What `key` resolves to with this map over `seeds`.
    func resolved(
        _ key: GestureKey,
        _ seeds: [GestureKey: GestureAction]
    ) -> GestureAction? {
        guard let entry = entries[key] else { return seeds[key] }
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

    /// The seeds on `⌃⌥` (#1873 ▸ Ruling 2026-11-15); a reader
    /// takes `seeds(on:)`, which moves them onto the stored base
    /// (#3444). The trackpad ladder: two fingers move between
    /// windows, three between Spaces and their overview, four
    /// between screens; every consumed slot holds ⌃⌥, so a bare
    /// macOS gesture stays macOS's. ⌃⌥ drag moves and ⌃⌥⇧ drag
    /// resizes, ⇧ being the variant as on the keyboard ladder.
    static let standardSeeds: [GestureKey: GestureAction] = [
        // A stray four-finger tap dims or clears the screen, and the
        // same tap undoes it; KiwiHub keeps ⌃⌥K.
        GestureKey(.tap4): navigation("kiwivision.toggle()"),
        GestureKey(.tap3): navigation("KiwiDesk.focus_space_last()"),
        GestureKey(.drag, pan): .grab(.move),
        GestureKey(.drag, pan.union(.shift)): .grab(.resize),
        GestureKey(.swipe2, pan): .family(.focus),
        GestureKey(.swipe3, pan): .split(
            GestureSplit(
                axes: [.leftRight: .space],
                arms: [.up: navigationStep(KiwiHubSide.desktops.lua)]
            )
        ),
        GestureKey(.swipe4, pan): .family(.display),
        GestureKey(.wheel, pan): .family(.walk),
        // ⌃⌥ alone on a mouse: the wheel walks, sideways switches
        // Spaces (#3281); the trackpad keeps ⌃⌥⌘ for the step.
        GestureKey(.wheelX, pan): .family(.space),
        GestureKey(.swipe2, step): .family(.space),
        // Clockwise the next layout, counter-clockwise the previous.
        GestureKey(.rotate, pan): .family(.layout),
        GestureKey(.spread, pan): navigation("KiwiDesk.toggle_maximized()"),
        GestureKey(.pinchTogether, pan): navigation(
            KiwiHubSide.desktops.lua
        ),
        GestureKey(.pinchTogether4, pan): navigation(
            KiwiHubSide.windows.lua
        ),
    ]

    private static func navigationStep(_ lua: String) -> LuaAction {
        LuaAction(lua: lua, kind: .navigation)
    }

    private static func navigation(_ lua: String) -> GestureAction {
        .run(navigationStep(lua))
    }

    /// The bound keys once `base` lies over the seeds on
    /// `shortcutBase` and `profile` over that. A refused binding is
    /// dropped, since a hand-edited file reaches what the verb
    /// refuses, and so is a click or a hover_move whose keys a drag
    /// holds: one press starts one thing, and a hover grab on those
    /// keys would end at the press.
    public static func resolved(
        base: GestureMap,
        profile: GestureMap?,
        shortcutBase: ShortcutBase
    ) -> [GestureKey: GestureAction] {
        var out = seeds(on: shortcutBase)
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
        profile: GestureMap?,
        shortcutBase: ShortcutBase
    ) -> GestureRefusal? {
        let resolved = Self.resolved(
            base: base,
            profile: profile,
            shortcutBase: shortcutBase
        )
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
