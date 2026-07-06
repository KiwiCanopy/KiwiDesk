import Carbon.HIToolbox
import Foundation

/// Resolves a virtual key code to its base character on the
/// *active* keyboard layout via `UCKeyTranslate`, so the
/// keybinding editor renders layout-correct glyphs — a German
/// layout shows `+` where a US layout shows `]` (#23). Returns nil
/// for keys with no printable base character (arrows, function
/// keys); `ComboSymbols` then falls back to a fixed glyph.
///
/// Translation uses no modifier state, so it yields the key's base
/// glyph (the modifiers are shown separately as ⌃⌥⇧⌘). The current
/// layout is queried first, with the ASCII-capable layout as a
/// fallback for input sources (some IMEs) that expose no Unicode
/// layout data.
enum LayoutKeyGlyph {
    static func char(for keyCode: UInt32) -> String? {
        guard let source = currentSource() ?? asciiSource()
        else { return nil }
        return translate(keyCode: keyCode, source: source)
    }

    private static func currentSource() -> TISInputSource? {
        TISCopyCurrentKeyboardLayoutInputSource()?
            .takeRetainedValue()
    }

    private static func asciiSource() -> TISInputSource? {
        TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
            .takeRetainedValue()
    }

    private static func translate(
        keyCode: UInt32,
        source: TISInputSource
    ) -> String? {
        guard
            let pointer = TISGetInputSourceProperty(
                source,
                kTISPropertyUnicodeKeyLayoutData
            )
        else { return nil }
        let layout = Unmanaged<CFData>
            .fromOpaque(pointer)
            .takeUnretainedValue()
        // Keep `source` alive across UCKeyTranslate: it owns the
        // layout data (a CF *Get*, not retained), which must not
        // be released while UCKeyTranslate dereferences it.
        return withExtendedLifetime(source) { () -> String? in
            guard let bytes = CFDataGetBytePtr(layout) else {
                return nil
            }
            let keyLayout = UnsafeRawPointer(bytes)
                .assumingMemoryBound(to: UCKeyboardLayout.self)
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                keyLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,  // no modifiers → the key's base glyph
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeys,
                chars.count,
                &length,
                &chars
            )
            guard status == noErr, length > 0 else { return nil }
            let text = String(utf16CodeUnits: chars, count: length)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }
}
