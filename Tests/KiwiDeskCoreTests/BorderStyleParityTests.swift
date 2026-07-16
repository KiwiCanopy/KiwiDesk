import Foundation
import Testing

@testable import KiwiDeskCore

/// Structural + round-trip parity for `BorderStyle`'s manual
/// sparse `Codable` (#278). A new field forgotten in `CodingKeys`
/// or the decode becomes a red build here — not a silent
/// inherit-the-default bug (AGENTS.md §5, parity-tests rule).
/// Reflection primitives live in `ReflectionParity.swift`.
@Suite("Border field-list parity")
struct BorderStyleParityTests {
    /// A fixture that differs from the default on every field, so
    /// the round-trip below is forget-proof (`expectRoundTrips`
    /// asserts each field changed, then survives decode ↔ encode).
    static func everyField() -> BorderStyle {
        var style = BorderStyle()
        style.enabled = false
        style.width = 7
        style.focusedColor = "#111111"
        style.unfocusedEnabled = true
        style.unfocusedColor = "#222222"
        style.cornerStyle = .square
        return style
    }

    @Test("CodingKeys cover every field")
    func keyParity() {
        #expect(
            keyStrings(BorderStyle.CodingKeys.allCases)
                == Set(fieldNames(BorderStyle()).map(snakeCased))
        )
    }

    @Test("Round-trips, touching every field")
    func roundTrip() throws {
        try expectRoundTrips(
            Self.everyField(),
            from: BorderStyle()
        )
    }

    @Test("Missing keys fall back to defaults")
    func decodeEmpty() throws {
        let decoded = try JSONDecoder().decode(
            BorderStyle.self,
            from: Data("{}".utf8)
        )
        #expect(decoded == BorderStyle())
    }

    @Test("fittingGaps sizes gaps to the full outward reach")
    func fittingGaps() {
        var style = BorderStyle()
        style.width = 10
        // Pure outset: reach = the full width.
        let focused = style.fittingGaps()
        #expect(focused.outer.top == 10)
        #expect(focused.outer.left == 10)
        #expect(focused.inner.horizontal == 10)
        #expect(focused.inner.vertical == 10)
        // Both: inner gaps double (two neighbouring rings).
        style.unfocusedEnabled = true
        #expect(style.fittingGaps().inner.horizontal == 20)
        #expect(style.fittingGaps().outer.top == 10)
        // Square reaches outward by the full width too.
        style.unfocusedEnabled = false
        style.cornerStyle = .square
        #expect(style.fittingGaps().outer.top == 10)
    }

    @Test("Width clamps into range, raw value preserved")
    func widthClamp() {
        var style = BorderStyle()
        style.width = 1000
        #expect(style.clampedWidth == BorderStyle.maxWidth)
        style.width = -5
        #expect(style.clampedWidth == BorderStyle.minWidth)
        style.width = 4
        #expect(style.clampedWidth == 4)
    }
}
