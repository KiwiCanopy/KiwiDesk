import AppKit

/// A chord drawn in an `NSMenuItem`'s native key-equivalent column —
/// the status item's rows (#1381) and the bar menus' (#2869) — so
/// #2601's sided-modifier rule lives once.
extension KeyCombo {
    /// Sets `item`'s key equivalent to this chord. A chord with a
    /// left- or right-only modifier, or a key with no menu glyph,
    /// leaves `item` untouched. `layoutChar` is the active layout's
    /// base character for a key code (the GUI's `LayoutKeyGlyph`).
    @MainActor public func applyMenuEquivalent(
        to item: NSMenuItem,
        layoutChar: (UInt32) -> String?
    ) {
        // A menu key equivalent has no side, so drawing `R⌘H` as
        // `⌘H` would promise the left key too (#2601).
        guard !modifiers.isSided else { return }
        guard let key = Self.menuKey(for: keyCode, layoutChar: layoutChar)
        else { return }
        var mask: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) { mask.insert(.control) }
        if modifiers.contains(.option) { mask.insert(.option) }
        if modifiers.contains(.shift) { mask.insert(.shift) }
        if modifiers.contains(.command) { mask.insert(.command) }
        item.keyEquivalent = key
        item.keyEquivalentModifierMask = mask
    }

    private static func menuKey(
        for code: UInt32,
        layoutChar: (UInt32) -> String?
    ) -> String? {
        let special: [UInt32: String] = [
            36: "\r", 76: "\u{3}", 48: "\t", 49: " ",
            51: "\u{8}", 117: "\u{7F}", 53: "\u{1B}",
            123: "\u{F702}", 124: "\u{F703}",
            125: "\u{F701}", 126: "\u{F700}",
            115: "\u{F729}", 119: "\u{F72B}",
            116: "\u{F72C}", 121: "\u{F72D}",
            122: "\u{F704}", 120: "\u{F705}",
            99: "\u{F706}", 118: "\u{F707}",
            96: "\u{F708}", 97: "\u{F709}",
            98: "\u{F70A}", 100: "\u{F70B}",
            101: "\u{F70C}", 109: "\u{F70D}",
            103: "\u{F70E}", 111: "\u{F70F}",
        ]
        return special[code] ?? layoutChar(code)?.lowercased()
    }
}
