import AppKit

/// Lua's alternatives to KiwiHub's ↑ and ↓ on the Pocket's grown
/// list (#3398): the arrow's code where a press is one, matched
/// with ⇧ dropped as KiwiHub does. Page and sideways keys stay
/// KiwiHub's, since the list has none of its own. Pure.
enum BarPeekListKeys {
    static func arrow(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        keys: KiwiHubKeys
    ) -> UInt16? {
        let held = modifiers.intersection(
            [.shift, .command, .option, .control]
        )
        let key =
            keys.key(for: combo(keyCode, held))
            ?? keys.key(for: combo(keyCode, held.subtracting(.shift)))
        switch key {
        case .up: return BarPeekPanel.ListKey.up
        case .down: return BarPeekPanel.ListKey.down
        default: return nil
        }
    }

    private static func combo(
        _ keyCode: UInt16,
        _ held: NSEvent.ModifierFlags
    ) -> KeyCombo {
        var modifiers: HotkeyModifiers = []
        if held.contains(.control) { modifiers.insert(.control) }
        if held.contains(.option) { modifiers.insert(.option) }
        if held.contains(.shift) { modifiers.insert(.shift) }
        if held.contains(.command) { modifiers.insert(.command) }
        return KeyCombo(keyCode: UInt32(keyCode), modifiers: modifiers)
    }
}
