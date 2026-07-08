import AppKit
import KiwiDeskCore

/// The chord being held right now — `ChordRecorder`'s live
/// mirror of the keyboard: a released key or modifier leaves
/// it immediately. A value type, so the recorder can stash a
/// copy as the burst candidate before a release downgrades
/// it.
struct PendingChord {
    var keyCode: UInt32
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool

    mutating func mirror(
        _ flags: NSEvent.ModifierFlags
    ) {
        command = flags.contains(.command)
        option = flags.contains(.option)
        control = flags.contains(.control)
        shift = flags.contains(.shift)
    }

    /// True when `other` holds a modifier this chord
    /// lacks (or vice versa) — the burst-candidate
    /// triggers.
    func lostModifier(since other: PendingChord) -> Bool {
        (other.command && !command)
            || (other.option && !option)
            || (other.control && !control)
            || (other.shift && !shift)
    }

    var combo: String? {
        KeyCombo.comboString(
            keyCode: keyCode,
            command: command,
            option: option,
            control: control,
            shift: shift
        )
    }
}

/// The chord as it stood before a release downgraded it,
/// stamped so `ChordRecorder` can tell a release burst (locks
/// the chord) from a slow disassembly (expires; the preview
/// has already shown the smaller truth).
struct BurstCandidate {
    let combo: String
    let at: Date
}

extension ChordRecorder {
    /// The held modifiers in display order (⌃⌥⇧⌘). A
    /// modifier-only chord is not recordable (Carbon hotkeys
    /// need a base key) — the preview makes that visible.
    static func modifierSymbols(
        _ flags: NSEvent.ModifierFlags
    ) -> String {
        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }
        return symbols
    }
}
