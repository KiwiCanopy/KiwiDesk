import Carbon.HIToolbox
import Foundation

/// Resolves virtual key codes to base characters via UCKeyTranslate (#23).
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
