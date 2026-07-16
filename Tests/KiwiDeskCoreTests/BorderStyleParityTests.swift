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

    @Test("fittingGaps sizes gaps to the true outward reach")
    func fittingGaps() {
        var style = BorderStyle()
        style.width = 10
        // Rounded reach = 10 − 1 (inner) = 9, not the raw width.
        let focused = style.fittingGaps()
        #expect(focused.outer.top == 9)
        #expect(focused.outer.left == 9)
        #expect(focused.inner.horizontal == 9)
        #expect(focused.inner.vertical == 9)
        // Both: inner gaps double (two neighbouring rings).
        style.unfocusedEnabled = true
        #expect(style.fittingGaps().inner.horizontal == 18)
        #expect(style.fittingGaps().outer.top == 9)
        // Square tucks inward, so it reaches far less than its
        // width: 10 − ceil-tuck → ceil(10 − 4.686) = 6.
        style.unfocusedEnabled = false
        style.cornerStyle = .square
        #expect(style.fittingGaps().outer.top == 6)
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
