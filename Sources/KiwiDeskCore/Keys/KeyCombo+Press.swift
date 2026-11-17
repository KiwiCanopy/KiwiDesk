import AppKit

/// A key press an `NSEvent` delivered, as a chord: its either-side
/// ⌃ ⌥ ⇧ ⌘, the inverse of `menuModifiers`.
extension KeyCombo {
    public init(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        var modifiers: HotkeyModifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        self.init(keyCode: UInt32(keyCode), modifiers: modifiers)
    }
}

extension KiwiHubKeys {
    /// The built-in key a press stands in for: the chord itself,
    /// else with ⇧ dropped, so ⇧ moves as with the arrows (#2600).
    /// KiwiHub and the Pocket list (#3398) both ask here.
    public func key(forPress combo: KeyCombo) -> KiwiHubKey? {
        key(for: combo)
            ?? key(
                for: KeyCombo(
                    keyCode: combo.keyCode,
                    modifiers: combo.modifiers.subtracting(.shift)
                )
            )
    }
}
