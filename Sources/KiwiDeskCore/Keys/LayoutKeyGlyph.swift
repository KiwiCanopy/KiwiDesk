import Carbon.HIToolbox
import Foundation

/// Resolves virtual key codes to base characters on the ACTIVE
/// layout via UCKeyTranslate (#23) — no modifier state, so the
/// base glyph (modifiers render separately). Nil for keys with
/// no printable base; `ComboSymbols` then uses a fixed glyph.
/// The ASCII-capable layout is the fallback for input sources
/// (some IMEs) that expose no Unicode layout data.
public enum LayoutKeyGlyph {
    public static func char(for keyCode: UInt32) -> String? {
        guard let source = currentSource() ?? asciiSource()
        else { return nil }
        return translate(keyCode: keyCode, source: source)
    }

    /// The main-block key code that types `letter` unshifted on the
    /// active layout, or on the ASCII-capable one macOS matches ⌘
    /// shortcuts on while a Cyrillic or Greek source is active
    /// (#3599); nil where no key types it.
    public static func keyCode(typing letter: String) -> UInt32? {
        let current = currentSource().flatMap {
            isASCIICapable($0) ? $0 : nil
        }
        guard let source = current ?? asciiSource() else { return nil }
        return mainBlockCodes.first {
            translate(keyCode: $0, source: source)?.lowercased()
                == letter
        }
    }

    /// The main block's key codes, ascending; the keypad, arrows
    /// and function keys all sit above 50.
    private static let mainBlockCodes: [UInt32] = Set(
        KeyCombo.keyCodes.values
    ).filter { $0 <= 50 }.sorted()

    private static func isASCIICapable(_ source: TISInputSource) -> Bool {
        guard
            let pointer = TISGetInputSourceProperty(
                source,
                kTISPropertyInputSourceIsASCIICapable
            )
        else { return false }
        let flag = Unmanaged<CFBoolean>.fromOpaque(pointer)
            .takeUnretainedValue()
        return CFBooleanGetValue(flag)
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
