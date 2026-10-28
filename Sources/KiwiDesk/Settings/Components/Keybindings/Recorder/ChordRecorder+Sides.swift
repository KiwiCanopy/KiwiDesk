import AppKit
import KiwiDeskCore

/// What a `.combo` recording keeps of a modifier's side (#2601),
/// handed to the recorder while the switch is on.
struct RecorderSides: Equatable {
    /// The Hyper key. Where it is one side of a modifier, the other
    /// side records plain: only one key can make that modifier
    /// (#2601 ▸ Ruling 4).
    var hyperKey: HyperSourceKey?

    /// The modifiers a press holding `flags` records, each side read
    /// from the event's own device bits through Core's one reader.
    /// Both sides down records plain, as does the Hyper key's
    /// modifier.
    func modifiers(_ flags: NSEvent.ModifierFlags) -> HotkeyModifiers {
        let held = HotkeyModifiers.held(
            by: CGEventFlags(rawValue: UInt64(flags.rawValue))
        )
        var out = held.unsided
        for kind in ModifierKind.allCases
        where held.contains(kind.plain)
            && kind != hyperKey?.modifierSide?.kind
        {
            let down = ModifierSide.allCases.filter {
                held.contains(.side($0, of: kind))
            }
            if down.count == 1 { out.insert(.side(down[0], of: kind)) }
        }
        return out
    }
}

extension ChordRecorder {
    /// The combo a key press records: sided while `sides` is handed
    /// in, save under a held Hyper, whose row takes no side.
    static func combo(
        keyCode: UInt16,
        flags: NSEvent.ModifierFlags,
        hyper: Bool,
        sides: RecorderSides?
    ) -> String? {
        if let sides, !hyper {
            return KeyCombo(
                keyCode: UInt32(keyCode),
                modifiers: sides.modifiers(flags)
            ).comboString()
        }
        return KeyCombo.comboString(
            keyCode: UInt32(keyCode),
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift),
            hyper: hyper
        )
    }

    /// `.combo` mode's preview: the held modifiers, Hyper leading,
    /// with the sides a press would record.
    static func preview(
        _ flags: NSEvent.ModifierFlags,
        hyper: Bool,
        sides: RecorderSides?
    ) -> String {
        if let sides, !hyper {
            return ChordGlyphs.modifiers(sides.modifiers(flags))
        }
        return (hyper ? ComboSymbols.hyperGlyph : "")
            + modifierSymbols(flags)
    }
}
