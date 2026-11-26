import AppKit
import KiwiDeskCore

/// The last-app opener's chords as KiwiHub reads them: its back
/// key and its own press (#3135, #3667).
extension JumpKey {
    /// The Windows side's back key: the last-app opener's chord
    /// with ⇧ added, as registered (#3135, owner 2026-11-09). None
    /// for no opener, a tap, a chord already holding ⇧, or a bare
    /// ⇥, whose ⇧ form is the previous side.
    static func back(of opener: KeyCombo?) -> KeyCombo? {
        guard let opener, !opener.isTap else { return nil }
        let chord = opener.registered
        guard !chord.modifiers.contains(.shift),
            !(UInt16(chord.keyCode) == tab && chord.modifiers.isEmpty)
        else { return nil }
        return KeyCombo(
            keyCode: chord.keyCode,
            modifiers: chord.modifiers.union(.shift)
        )
    }

    /// Whether the press is the Windows side's back key, the one
    /// match `of` and the panel's opener latch share (#3135, #3168).
    static func isBack(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        scope: JumpScope,
        back: KeyCombo?
    ) -> Bool {
        guard scope == .windows, let back else { return false }
        let held = modifiers.intersection(
            [.shift, .command, .option, .control]
        )
        return KeyCombo(keyCode: keyCode, flags: held) == back
    }

    /// Whether the press is the last-app opener's own chord, read
    /// as `isBack` reads its ⇧ form (#3667).
    static func isOpener(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        opener: KeyCombo?
    ) -> Bool {
        guard let opener, !opener.isTap,
            !opener.modifiers.contains(.hyper),
            let code = UInt16(exactly: opener.keyCode)
        else { return false }
        let held = modifiers.intersection(
            [.shift, .command, .option, .control]
        )
        return keyCode == code
            && KeyCombo(keyCode: keyCode, flags: held) == opener.registered
    }
}
