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

/// One action's chord and start; an empty chord is off.
public struct ModifierDragBinding: Equatable, Sendable {
    public var chord: ScrollChord
    public var start: ModifierDragStart

    public init(chord: ScrollChord, start: ModifierDragStart = .drag) {
        self.chord = chord
        self.start = start
    }

    public var isOff: Bool { chord.isEmpty }
}

/// Why a modifier drag's chord is refused: one modifier alone is
/// a click macOS and apps already read, and the two actions never
/// share a chord. Core names it; the CLI and the recorder word it.
public enum ModifierDragRefusal: Equatable, Sendable {
    case singleModifier
    /// The other action, named, already holds these keys.
    case otherAction(ModifierDragAction)

    /// The refusal for `chord` beside `other`, the chord `heldBy`
    /// holds; empty (off) is always accepted.
    public static func of(
        _ chord: ScrollChord,
        other: ScrollChord,
        heldBy: ModifierDragAction
    ) -> ModifierDragRefusal? {
        guard !chord.isEmpty else { return nil }
        if chord.rawValue.nonzeroBitCount < 2 { return .singleModifier }
        if chord == other { return .otherAction(heldBy) }
        return nil
    }
}

/// The modifier drags' settings (#2447): global, in `gui.json`,
/// on by default with the button held. Lua writes them through
/// `modifier_drag.*`; the tap reads `sanitized`.
public struct ModifierDragSettings: Equatable, Sendable {
    public var move: ModifierDragBinding
    public var resize: ModifierDragBinding

    public static let defaults = ModifierDragSettings(
        move: ModifierDragBinding(chord: [.control, .command]),
        resize: ModifierDragBinding(chord: [.control, .option])
    )

    public init(move: ModifierDragBinding, resize: ModifierDragBinding) {
        self.move = move
        self.resize = resize
    }

    public subscript(action: ModifierDragAction) -> ModifierDragBinding {
        get { action == .move ? move : resize }
        set {
            if action == .move { move = newValue } else { resize = newValue }
        }
    }

    /// The recorder's and the verbs' refusals, applied once more
    /// to what a hand-edited file can reach: a lone modifier turns
    /// that action off, and a shared chord stays the move's.
    public var sanitized: ModifierDragSettings {
        var result = self
        if ModifierDragRefusal.of(move.chord, other: [], heldBy: .resize)
            != nil
        {
            result.move.chord = []
        }
        if ModifierDragRefusal.of(
            resize.chord,
            other: result.move.chord,
            heldBy: .move
        ) != nil {
            result.resize.chord = []
        }
        return result
    }

    /// Whether any action is on.
    public var isOn: Bool { !move.isOff || !resize.isOff }
}
