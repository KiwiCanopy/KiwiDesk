import AppKit

extension BarPeekPanel {
    /// The keys a grown list uses. `KiwiHubKeyRefusal.panelKeeps`
    /// holds each one under any modifier, so no Lua alternative
    /// shadows it (`PocketListKeyParityTests`).
    enum ListKey {
        static let escape: UInt16 = 53
        static let down: UInt16 = 125
        static let up: UInt16 = 126
        static let enter: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let all = [escape, down, up, enter, keypadEnter]
        /// A key the list does not use: it closes the list.
        static let closing = UInt16.max
    }

    /// The list key a press stands for: a KiwiHub ↑ ↓ alternative
    /// as its arrow (#3398), page and sideways alternatives staying
    /// KiwiHub's; a ⌘ chord as itself only while the key that
    /// opened the list is still held (#2974), else it closes.
    func listKey(_ code: UInt16, _ flags: NSEvent.ModifierFlags) -> UInt16 {
        let held = flags.intersection(
            [.shift, .command, .option, .control]
        )
        switch keys().key(forPress: KeyCombo(keyCode: code, flags: held)) {
        case .up: return ListKey.up
        case .down: return ListKey.down
        default: break
        }
        guard held.contains(.command) else { return code }
        let walks =
            panel?.walksHeldKeys == true && ListKey.all.contains(code)
        return walks ? code : ListKey.closing
    }
}
