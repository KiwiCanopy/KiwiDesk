import Foundation
import Testing

@testable import KiwiDeskCore

/// The name table's matching rules and the `meta` reader, on
/// hand-built fonts so each clause names its own input.
@Suite("App font glyph map")
struct AppFontGlyphMapTests {
    /// A one-table sfnt whose `meta` carries `payload` as its
    /// only data map, filed under `tag`.
    private func font(_ payload: String, tag: String = "APPM") -> Data {
        let body = Array(payload.utf8)
        var bytes: [UInt8] = []
        func u16(_ v: UInt16) { bytes += [UInt8(v >> 8), UInt8(v & 0xFF)] }
        func u32(_ v: UInt32) {
            bytes += (0..<4).map { UInt8(v >> (24 - 8 * $0) & 0xFF) }
        }
        func tag4(_ t: String) { bytes += Array(t.utf8) }
        let metaOffset: UInt32 = 12 + 16
        let metaLength = UInt32(16 + 12 + body.count)
        u32(0x0001_0000)
        u16(1)
        u16(0)
        u16(0)
        u16(0)
        tag4("meta")
        u32(0)
        u32(metaOffset)
        u32(metaLength)
        u32(1)  // meta version
        u32(0)  // flags
        u32(0)  // reserved
        u32(1)  // data map count
        tag4(tag)
        u32(16 + 12)
        u32(UInt32(body.count))
        bytes += body
        return Data(bytes)
    }

    @Test("The APPM payload decodes; null names map nothing")
    func decodesPayload() throws {
        let data = font(
            """
            {"version": 1, "release": "3.0.0", "icons": [
              [":zed:", 59905, ["Zed", "Zed Preview"]],
              [":util:", 59906, null]
            ]}
            """
        )
        let map = try #require(AppFontGlyphMap.load(fontData: data))
        #expect(map.ligature(for: "Zed Preview") == ":zed:")
        #expect(map.ligatures == [":zed:"])
    }

    @Test("A different data map tag or schema version is refused")
    func refusesOtherShapes() {
        let icons = #""icons": [[":zed:", 1, ["Zed"]]]"#
        #expect(
            AppFontGlyphMap.load(
                fontData: font("{\"version\": 1, \(icons)}", tag: "XXXX")
            ) == nil
        )
        #expect(
            AppFontGlyphMap.load(
                fontData: font("{\"version\": 2, \(icons)}")
            ) == nil
        )
    }

    @Test("A truncated font answers nil")
    func truncatedFont() {
        let data = font(#"{"version": 1, "icons": []}"#)
        #expect(AppFontGlyphMap.load(fontData: data.prefix(40)) == nil)
    }

    @Test("A trailing star matches by prefix, case-sensitively")
    func prefixMatch() {
        let map = AppFontGlyphMap(["Adobe Photoshop*": ":photoshop:"])
        #expect(map.ligature(for: "Adobe Photoshop 2026") == ":photoshop:")
        #expect(map.ligature(for: "Adobe Photoshop") == ":photoshop:")
        #expect(map.ligature(for: "adobe photoshop 2026") == nil)
    }

    @Test("An exact name beats a prefix; a longer prefix a shorter")
    func precedence() {
        let map = AppFontGlyphMap([
            (name: "Adobe*", ligature: ":adobe:"),
            (name: "Adobe Bridge*", ligature: ":bridge:"),
            (name: "Adobe Bridge Beta", ligature: ":beta:"),
        ])
        #expect(map.ligature(for: "Adobe Bridge 2026") == ":bridge:")
        #expect(map.ligature(for: "Adobe Bridge Beta") == ":beta:")
        #expect(map.ligature(for: "Adobe XD") == ":adobe:")
    }

    @Test("Degenerate entries are dropped, not served")
    func degenerateEntriesDropped() {
        let map = AppFontGlyphMap([
            (name: "Ghost", ligature: ""),
            (name: "", ligature: ":ok:"),
            (name: "*", ligature: ":ok:"),
            (name: "Real", ligature: ":ok:"),
        ])
        #expect(map.ligature(for: "Ghost") == nil)
        #expect(map.ligature(for: "") == nil)
        #expect(map.ligature(for: "Anything") == nil)
        #expect(map.ligature(for: "Real") == ":ok:")
    }
}
