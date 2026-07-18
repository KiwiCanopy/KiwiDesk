import Foundation
import Testing

@testable import KiwiDeskCore

/// #386: caller-supplied config/IPC numbers must never trap a raw
/// `Double → Int` conversion. `Int(1e300)`, `Int(.nan)`, and
/// `Int(.infinity)` all crash the process; a single mistyped Lua
/// or JSON number could otherwise take down the WM.
@Suite("Number → Int trap safety (#386)")
struct NumberTrapSafetyTests {
    @Test("Double.finiteInt rejects out-of-range and non-finite")
    func finiteInt() {
        #expect((3.0).finiteInt == 3)
        #expect((-7.0).finiteInt == -7)
        #expect((1e300).finiteInt == nil)
        #expect((-1e300).finiteInt == nil)
        #expect(Double.nan.finiteInt == nil)
        #expect(Double.infinity.finiteInt == nil)
        // The boundary: Double(Int.max) rounds up to 2^63, which
        // is NOT a valid Int — the strict `<` bound rejects it.
        #expect(Double(Int.max).finiteInt == nil)
        // ...but the low bound and the largest representable value
        // below it are admitted, not wrongly rejected.
        #expect(Double(Int.min).finiteInt == Int.min)
        #expect(Double(Int.max).nextDown.finiteInt != nil)
    }

    @Test("resize.step decodes clamped, so Int() reads never trap")
    func resizeStepDecodeClamped() throws {
        let huge = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(#"{"resize":{"step":1e300}}"#.utf8)
        )
        #expect(huge.resizeStep <= 10_000)
        #expect(huge.resizeStep.isFinite)
        // A sane in-range value is preserved.
        let ok = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(#"{"resize":{"step":75}}"#.utf8)
        )
        #expect(ok.resizeStep == 75)
    }

    @Test("JSONValue.intValue is trap-safe")
    func intValue() {
        #expect(JSONValue.number(42).intValue == 42)
        #expect(JSONValue.number(1e300).intValue == nil)
        #expect(JSONValue.number(.nan).intValue == nil)
        #expect(JSONValue.string("5").intValue == 5)
        #expect(JSONValue.string("1e300").intValue == nil)
    }

    @Test("LuaValue.intValue is trap-safe")
    func luaIntValue() {
        #expect(LuaValue.number(9).intValue == 9)
        #expect(LuaValue.number(1e300).intValue == nil)
        #expect(LuaValue.number(.infinity).intValue == nil)
    }

    @Test("JSONValue.stringValue never traps on a huge whole number")
    func stringValue() {
        // A whole number prints as an Int...
        #expect(JSONValue.number(3).stringValue == "3")
        // ...a fractional one keeps its Double form...
        #expect(JSONValue.number(3.5).stringValue == "3.5")
        // ...and a huge whole number falls back to Double
        // formatting instead of trapping via `Int(1e300)`.
        #expect(JSONValue.number(1e300).stringValue == String(1e300))
    }

    @Test("space_bar.set_spring_delay clamps a huge value, no trap")
    func springDelayHuge() throws {
        let parsed = SpaceBarCommandSetting.parse(
            field: "spring_delay",
            args: [.number(1e300)]
        )
        var style = SpaceBarStyle()
        try parsed.get().apply(to: &style)
        #expect(
            style.springDelay
                == SpaceBarStyle.springDelayRange.upperBound
        )
    }

    @Test("space_bar.set_glyph_cap clamps a huge value, no trap")
    func glyphCapHuge() throws {
        let parsed = SpaceBarCommandSetting.parse(
            field: "glyph_cap",
            args: [.number(1e300)]
        )
        var style = SpaceBarStyle()
        try parsed.get().apply(to: &style)
        #expect(
            style.glyphCap == SpaceBarStyle.glyphCapRange.upperBound
        )
    }

    @Test("A non-finite setting value is rejected, not clamped")
    func nonFiniteRejected() {
        #expect(
            (try? SpaceBarCommandSetting.parse(
                field: "spring_delay",
                args: [.number(.nan)]
            ).get()) == nil
        )
        #expect(
            (try? SpaceBarCommandSetting.parse(
                field: "glyph_cap",
                args: [.number(.infinity)]
            ).get()) == nil
        )
    }
}
