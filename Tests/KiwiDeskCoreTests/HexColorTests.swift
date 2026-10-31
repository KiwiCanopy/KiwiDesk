import Testing

@testable import KiwiDeskCore

@Suite("Hex color parsing")
struct HexColorTests {
    @Test("6- and 8-digit hex parse, junk does not")
    func parse() throws {
        let rgb = try #require(
            HexColor.parse("#4E9F3D")
        )
        #expect(rgb.alpha == 1)
        #expect(abs(rgb.green - 0x9F / 255.0) < 0.001)
        let rgba = try #require(
            HexColor.parse("8B5E3C40")
        )
        #expect(abs(rgba.alpha - 0x40 / 255.0) < 0.001)
        #expect(HexColor.parse("#12345") == nil)
        #expect(HexColor.parse("kiwi") == nil)
        #expect(HexColor.parse("#GG5E3C") == nil)
    }
}
