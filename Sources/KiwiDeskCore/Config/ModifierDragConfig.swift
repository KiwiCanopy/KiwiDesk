import Foundation

/// What a modifier drag does to the window under the pointer
/// (#2447).
public enum ModifierDragAction: String, CaseIterable, Sendable {
    /// Moves it: drag swap on a tiled window, the frame on a float.
    case move
    /// Resizes it from the corner or edge nearest the grab point.
    case resize
}

/// How a modifier drag starts (#2447 ruling 2026-11-08): with the
/// left button held, or by moving the pointer while the chord is
/// held, no click.
public enum ModifierDragStart: String, CaseIterable, Sendable {
    /// "+ drag": the press starts it, the release ends it.
    case drag
    /// "+ move (no click)": holding the chord starts it, letting a
    /// key go ends it.
    case hover
}

/// One grab binding: the action, its keys and how it starts. An
/// empty chord is off.
public struct ModifierDragBinding: Equatable, Sendable {
    public var action: ModifierDragAction
    public var chord: ScrollChord
    public var start: ModifierDragStart

    public init(
        _ action: ModifierDragAction,
        chord: ScrollChord,
        start: ModifierDragStart = .drag
    ) {
        self.action = action
        self.chord = chord
        self.start = start
    }

    public var isOff: Bool { chord.isEmpty }
}

/// The pointer tap's grab bindings (#2447, #3199): every `drag` and
/// `hover_move` row of the gesture list, in its order. A press or a
/// move begins the binding whose keys and start it matches, so one
/// action may be bound any number of times.
public struct ModifierDragSettings: Equatable, Sendable {
    public var bindings: [ModifierDragBinding]

    /// The seeds' grabs, which hold until the first apply.
    public static let defaults = ModifierDragSettings(
        resolved: GestureSeeds.seeds
    )

    /// Every `drag` and `hover_move` row of a resolved list, in its
    /// order, a `drag` row starting on a press and a `hover_move`
    /// row on the keys alone.
    public init(resolved: [GestureKey: GestureAction]) {
        var bindings: [ModifierDragBinding] = []
        for key in resolved.keys.sorted() {
            guard case .grab(let grab) = resolved[key],
                let start = key.input.grabStart
            else { continue }
            bindings.append(
                ModifierDragBinding(grab, chord: key.keys, start: start)
            )
        }
        self.init(bindings)
        self = sanitized
    }

    public init(_ bindings: [ModifierDragBinding] = []) {
        self.bindings = bindings
    }

    /// What a hand-edited file can reach, made one set of keys, one
    /// grab: off bindings leave, and of two on the same keys the
    /// first stays, whatever their start, since a hover grab on a
    /// drag's keys ends at its press.
    public var sanitized: ModifierDragSettings {
        var kept: [ModifierDragBinding] = []
        for binding in bindings where !binding.isOff {
            guard !kept.contains(where: { $0.chord == binding.chord })
            else { continue }
            kept.append(binding)
        }
        return ModifierDragSettings(kept)
    }

    /// The binding a sample on `chord` starting as `start` begins.
    public func binding(
        chord: ScrollChord,
        start: ModifierDragStart
    ) -> ModifierDragBinding? {
        bindings.first {
            !$0.isOff && $0.chord == chord && $0.start == start
        }
    }

    /// Whether any binding is on.
    public var isOn: Bool { bindings.contains { !$0.isOff } }
}
