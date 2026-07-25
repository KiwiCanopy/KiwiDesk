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
        style.glow = true
        style.drawOrder = .front
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

    @Test("Unfocused border defaults to visible neutral grey")
    func unfocusedDefaultColor() {
        #expect(BorderStyle().unfocusedColor == "#8E8E93CC")
    }

    @Test("fittingGaps sizes gaps to the true outward reach")
    func fittingGaps() {
        var style = BorderStyle()
        style.width = 10
        // Hidden overlap does not count toward visible reach.
        let focused = style.fittingGaps()
        #expect(focused.outer.top == 10)
        #expect(focused.outer.left == 10)
        #expect(focused.inner.horizontal == 10)
        #expect(focused.inner.vertical == 10)
        // Both: inner gaps double (two neighbouring rings).
        style.unfocusedEnabled = true
        #expect(style.fittingGaps().inner.horizontal == 20)
        #expect(style.fittingGaps().outer.top == 10)
        // Corner style does not change the visible thickness.
        style.unfocusedEnabled = false
        style.cornerStyle = .square
        #expect(style.fittingGaps().outer.top == 10)
    }

    @Test("fittingGaps adds the remaining gap after the reach")
    func fittingGapsRemaining() {
        var style = BorderStyle()
        style.width = 10
        // Visible reach 10 (#295 formula, focused-only):
        // outer = reach + r, inner = reach + r.
        let gaps = style.fittingGaps(remaining: 6)
        #expect(gaps.outer.top == 16)
        #expect(gaps.outer.left == 16)
        #expect(gaps.inner.horizontal == 16)
        #expect(gaps.inner.vertical == 16)
        // Unfocused shown: inner = 2 × reach + r — the
        // remaining is whitespace between the two rings, so it
        // is added once, not doubled.
        style.unfocusedEnabled = true
        let both = style.fittingGaps(remaining: 6)
        #expect(both.inner.horizontal == 26)
        #expect(both.outer.top == 16)
        // Square uses the same visible reach.
        style.unfocusedEnabled = false
        style.cornerStyle = .square
        #expect(style.fittingGaps(remaining: 4).outer.top == 14)
        // Zero remaining stays the plain fit; negative clamps.
        #expect(style.fittingGaps(remaining: 0).outer.top == 10)
        #expect(style.fittingGaps(remaining: -9).outer.top == 10)
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
