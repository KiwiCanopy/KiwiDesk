import Foundation

/// A gesture binding's identity (#3199 ruling ▸ Storage): the input
/// and the keys held with it, stored as `"wheel:control+option"`, or
/// the input alone where no key is held (`"tap4"`). One input may
/// appear many times with different keys.
public struct GestureKey: Hashable, Sendable, Comparable {
    public var input: GestureInput
    public var chord: ScrollChord

    public init(_ input: GestureInput, _ keys: ScrollChord = []) {
        self.input = input
        self.chord = keys
    }

    /// The wire spelling.
    public var spelling: String {
        chord.isEmpty ? input.rawValue : "\(input.rawValue):\(chord.spelling)"
    }

    /// Reads a wire spelling; nil for an unknown input or keys, and
    /// for any spelling but the canonical one, so two spellings
    /// never name one key.
    public init?(spelling text: String) {
        let parts = text.split(separator: ":", maxSplits: 1)
        guard let first = parts.first,
            let input = GestureInput(rawValue: String(first))
        else { return nil }
        var keys: ScrollChord = []
        if parts.count == 2 {
            guard let chord = ScrollChord(spelling: String(parts[1])) else {
                return nil
            }
            keys = chord
        }
        let key = GestureKey(input, keys)
        guard key.spelling == text else { return nil }
        self = key
    }

    /// Input order, then the keys' bits: the order a list shows.
    public static func < (lhs: GestureKey, rhs: GestureKey) -> Bool {
        let order = GestureInput.allCases
        let l = order.firstIndex(of: lhs.input) ?? 0
        let r = order.firstIndex(of: rhs.input) ?? 0
        return l != r ? l < r : lhs.chord.rawValue < rhs.chord.rawValue
    }
}

/// A directional family a swipe, a wheel or the side buttons bind;
/// the motion's direction is its argument (#3199 ▸ Families by
/// input). What each step does is the pan's runner's (#3200).
public enum GestureFamily: String, CaseIterable, Codable, Sendable {
    /// Focus the window that way; along a Scrolling row the row
    /// slides with the fingers (#3200 amendment).
    case focus
    case swap
    /// Focus the screen that way.
    case display
    /// Move the window to the next or previous track.
    case track
    /// Step between the screen's Spaces.
    case space
    /// The window list in order (#3200: a wheel's walk).
    case walk
}

/// A built-in or Lua action as an end key stores it (#3199 ▸ the
/// action picker): its Lua, its kind and what it says of itself.
/// `KeyBinding.action` is the end key's view of the same value, so
/// the two never drift.
public struct LuaAction: Hashable, Sendable {
    public var lua: String
    public var kind: KeyBinding.Kind
    public var meta: KeyBindingMeta

    public init(
        lua: String,
        kind: KeyBinding.Kind = .custom,
        meta: KeyBindingMeta = .none
    ) {
        self.lua = lua
        self.kind = kind
        self.meta = meta
    }
}

extension KeyBinding {
    /// The row's action, the three halves whole (#3199): the one
    /// door an end key and a gesture row read and write it through.
    public var action: LuaAction {
        get { LuaAction(lua: lua, kind: kind, meta: meta) }
        set {
            lua = newValue.lua
            kind = newValue.kind
            meta = newValue.meta
        }
    }
}

/// What one binding does (#3199 ▸ Stored value).
public enum GestureAction: Hashable, Sendable {
    case run(LuaAction)
    case family(GestureFamily)
    /// One action per direction; a missing direction does nothing.
    case split([GestureDirection: LuaAction])
    /// A pointer gesture's grab: the window moves, or resizes from
    /// the edge or corner nearest the pointer, while the keys are
    /// held; whether it starts on a press is the input's
    /// (`GestureInput.grabStart`).
    case grab(ModifierDragAction)

    /// A split, folded: an empty one is nil, which binds nothing.
    /// The one home of the fold every writer takes.
    public static func split(
        normalizing arms: [GestureDirection: LuaAction]
    ) -> GestureAction? {
        arms.isEmpty ? nil : .split(arms)
    }

    /// The Lua one motion runs toward `direction`, nil where it
    /// runs none.
    public func lua(toward direction: GestureDirection?) -> String? {
        switch self {
        case .run(let action): action.lua
        case .split(let arms): direction.flatMap { arms[$0]?.lua }
        case .family, .grab: nil
        }
    }
}

/// Why a binding is refused for its key. Core names it; the CLI
/// and the Settings card each word it.
public enum GestureRefusal: Equatable, Sendable {
    case emptyAction
    case needsModifier
    /// One modifier alone on a scroll belongs to macOS and apps
    /// (#1656): ⌃ + scroll is Zoom's.
    case singleModifierScroll
    /// macOS turns ⇧ + wheel into a sideways scroll.
    case shiftOnWheel
    case familyNotOffered
    /// A swipe, a wheel or the side buttons bind a family, or one
    /// action per direction; never one action for all of them.
    case directionalNeedsFamily
    /// A drag binds a grab alone; nothing else binds one.
    case grabOnlyOnDrag
    case noDirections
    /// A click or a hover_move on keys a drag holds: one press
    /// starts one thing, and a hover grab there would end at it.
    case keysHeldByDrag
}

extension GestureAction {
    /// The refusal for this action on `key`; nil when it stands.
    public func refusal(on key: GestureKey) -> GestureRefusal? {
        let input = key.input
        if input.needsModifier, key.chord.isEmpty { return .needsModifier }
        if input.isWheel || input.isPhasedScroll,
            key.chord.rawValue.nonzeroBitCount < 2
        {
            return .singleModifierScroll
        }
        if input.isWheel, key.chord.contains(.shift) { return .shiftOnWheel }
        switch self {
        case .grab:
            return input.isDrag ? nil : .grabOnlyOnDrag
        case _ where input.isDrag:
            return .grabOnlyOnDrag
        case .run(let action):
            if !input.directions.isEmpty { return .directionalNeedsFamily }
            return action.lua.trimmingCharacters(in: .whitespaces).isEmpty
                ? .emptyAction : nil
        case .family(let family):
            return input.families.contains(family) ? nil : .familyNotOffered
        case .split(let arms):
            if input.directions.isEmpty { return .noDirections }
            return arms.keys.allSatisfy(input.directions.contains)
                ? nil : .noDirections
        }
    }
}
