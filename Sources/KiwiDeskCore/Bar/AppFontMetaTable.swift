import Foundation

/// Reads one data map out of a TrueType font's `meta` table
/// (OpenType spec, `meta` version 1). Pure byte parsing, no
/// CoreText, so it runs off the main actor and in tests on
/// hand-built fonts. Every offset is bounds-checked: a bad
/// drop answers nil, never traps.
enum AppFontMetaTable {
    /// The payload the font files under `tag` (e.g. `"APPM"`),
    /// or nil when the font, its `meta` table or the data map
    /// is absent or malformed.
    static func dataMap(_ tag: String, in font: Data) -> Data? {
        let bytes = [UInt8](font)
        guard
            let tableCount = u16(bytes, at: 4),
            let meta = table("meta", count: tableCount, in: bytes),
            let mapCount = u32(bytes, at: meta + 12)
        else { return nil }
        for index in 0..<Int(mapCount) {
            let record = meta + 16 + index * 12
            // A count past the buffer ends the walk; a bogus
            // 0xFFFFFFFF would otherwise spin the whole range.
            guard record + 12 <= bytes.count else { return nil }
            guard
                self.tag(bytes, at: record) == tag,
                let offset = u32(bytes, at: record + 4),
                let length = u32(bytes, at: record + 8)
            else { continue }
            let start = meta + Int(offset)
            let end = start + Int(length)
            guard end <= bytes.count else { return nil }
            return Data(bytes[start..<end])
        }
        return nil
    }

    /// Byte offset of the table named `name`, from the sfnt
    /// table directory.
    private static func table(
        _ name: String,
        count: UInt16,
        in bytes: [UInt8]
    ) -> Int? {
        for index in 0..<Int(count) {
            let record = 12 + index * 16
            guard tag(bytes, at: record) == name else { continue }
            return u32(bytes, at: record + 8).map(Int.init)
        }
        return nil
    }

    private static func tag(_ bytes: [UInt8], at offset: Int) -> String? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return String(
            bytes: bytes[offset..<offset + 4],
            encoding: .isoLatin1
        )
    }

    private static func u16(_ bytes: [UInt8], at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= bytes.count else { return nil }
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    private static func u32(_ bytes: [UInt8], at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return bytes[offset..<offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
    }
}
