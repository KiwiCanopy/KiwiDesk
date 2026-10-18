import AppKit
import KiwiDeskCore

/// The recorder's static key tables and modifier formatting.
extension ChordRecorder {
    /// Each sided modifier's device-dependent bit (IOKit's
    /// `NX_DEVICE*KEYMASK`), keyed by `HyperSourceKey`'s own code;
    /// Caps Lock toggles, so its every report is a press (0).
    static let sideMask: [UInt16: UInt] = [
        HyperSourceKey.leftControl.keyCode: 0x0001,
        HyperSourceKey.leftShift.keyCode: 0x0002,
        HyperSourceKey.rightShift.keyCode: 0x0004,
        HyperSourceKey.leftCommand.keyCode: 0x0008,
        HyperSourceKey.rightCommand.keyCode: 0x0010,
        HyperSourceKey.leftOption.keyCode: 0x0020,
        HyperSourceKey.rightOption.keyCode: 0x0040,
        HyperSourceKey.rightControl.keyCode: 0x2000,
        HyperSourceKey.capsLock.keyCode: 0,
    ]

    /// The scroll chord a modifier set spells.
    static func scrollChord(_ flags: NSEvent.ModifierFlags) -> ScrollChord {
        var chord: ScrollChord = []
        if flags.contains(.control) { chord.insert(.control) }
        if flags.contains(.option) { chord.insert(.option) }
        if flags.contains(.shift) { chord.insert(.shift) }
        if flags.contains(.command) { chord.insert(.command) }
        return chord
    }

    /// Formats held modifiers in standard display order (⌃⌥⇧⌘).
    static func modifierSymbols(
        _ flags: NSEvent.ModifierFlags
    ) -> String {
        ScrollChordGlyphs.text(scrollChord(flags))
    }
}
