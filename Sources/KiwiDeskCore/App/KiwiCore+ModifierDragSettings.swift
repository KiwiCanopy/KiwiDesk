import Foundation

/// Where the modifier drags' settings reach the pointer tap
/// (#2447). Global only: no profile override, since the ruling
/// names none.
extension KiwiCore {
    /// The ONE apply: `base` sanitised, handed to the front's one
    /// door. A config load passes what it read; nil keeps what
    /// `init.lua`'s verbs left.
    func applyModifierDrag(_ base: ModifierDragSettings? = nil) {
        let raw = base ?? modifierDragBase
        modifierDragBase = raw
        let resolved = raw.sanitized
        // Said once per change, not on every re-apply.
        if resolved != raw, resolved != mouse.pointer.grabSettings {
            onLog("modifier_drag: refused chords turned off")
        }
        mouse.pointer.configure(grab: resolved)
    }

    /// The stored base, as written; `mouse.pointer.grabSettings`
    /// is its sanitised reading.
    var modifierDragBase: ModifierDragSettings {
        get { mouse.pointer.grabBase }
        set { mouse.pointer.grabBase = newValue }
    }

    /// `modifier_drag.*`: writes the base, which lasts until the
    /// next config load. No window moves, so no retile.
    func modifierDragCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        let action: ModifierDragAction
        switch command {
        case "modifier_drag.set_move": action = .move
        case "modifier_drag.set_resize": action = .resize
        default: return .fail("unknown command: \(command)")
        }
        guard
            let text = args.first?.stringValue,
            let chord = ScrollChord(spelling: text)
        else {
            return .fail(
                "expected modifiers like \"control+command\", "
                    + "or \"\" for off"
            )
        }
        var binding = modifierDragBase[action]
        if let raw = args.dropFirst().first?.stringValue {
            guard let start = ModifierDragStart(rawValue: raw) else {
                return .expected(ModifierDragStart.self)
            }
            binding.start = start
        }
        let other: ModifierDragAction = action == .move ? .resize : .move
        if let refusal = Self.modifierDragRefusal(
            chord,
            other: modifierDragBase[other].chord,
            heldBy: other
        ) {
            return .fail(refusal)
        }
        binding.chord = chord
        var base = modifierDragBase
        base[action] = binding
        applyModifierDrag(base)
        return .ok()
    }

    /// The refusals, in CLI English.
    static func modifierDragRefusal(
        _ chord: ScrollChord,
        other: ScrollChord,
        heldBy: ModifierDragAction
    ) -> String? {
        switch ModifierDragRefusal.of(chord, other: other, heldBy: heldBy) {
        case nil: return nil
        case .singleModifier:
            return "a modifier drag needs two or more modifiers"
        case .otherAction:
            return "the move and resize drags need different modifiers"
        }
    }
}
