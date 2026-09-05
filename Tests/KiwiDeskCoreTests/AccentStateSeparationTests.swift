import Foundation
import Testing

@testable import KiwiDeskCore

/// The accent seal's three state fills, under protanopia (#1198).
///
/// Since #1198 the seal says "available", "being pressed" and
/// "unavailable" by changing its FILL and nothing else — same
/// silhouette, same ink, same stroke. That makes the whole
/// enabled/disabled distinction a colour judgement, on a primary
/// that is green, which is the one hue protanopia takes. So the
/// pairs owe the same floor the bars' and the drag overlay's do.
///
/// Lives in this target because `ColorVision` does; both hexes
/// are PARSED from `SettingsTheme.swift`, so a retune moves the
/// measurement with it instead of leaving a stale copy behind (a
/// number-pin derives, never restates).
@Suite("Accent state separation")
struct AccentStateSeparationTests {
    private func themeSource() throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
            try #require(url.path != "/")
        }
        url.deleteLastPathComponent()
        let source = try String(
            contentsOf: url.appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsTheme.swift"
            ),
            encoding: .utf8
        )
        try #require(!source.isEmpty)
        return source
    }

    /// `let name = token(light: 0xAA_BB_CC, …)` → the light hex.
    /// All three state fills are fixed in both modes, which the
    /// token suite pins, so one hex is the whole colour.
    private func fill(
        _ name: String,
        in source: String
    ) throws -> String {
        let squashed =
            source
            .split(whereSeparator: \.isWhitespace)
            .joined()
        let start = try #require(
            squashed.range(of: "let\(name)=token(light:0x"),
            Comment(rawValue: "no such token: \(name)")
        )
        let hex = squashed[start.upperBound...]
            .prefix { $0.isHexDigit || $0 == "_" }
            .replacingOccurrences(of: "_", with: "")
        try #require(hex.count == 6)
        return "#" + hex
    }

    /// The rest fill against the disabled one — the one pair a
    /// user actually has to tell apart, since it is the whole
    /// answer to "does this button do anything".
    ///
    /// **`accentPressed` is deliberately not measured against
    /// `accentDisabled`, and this is where that is stated.** The
    /// two are never a discrimination: no two seal buttons are
    /// ever on screen together (the tour's pair are `if`/`else`
    /// branches), and a disabled control cannot enter the
    /// pressed state, so the colours are never adjacent in space
    /// or in time. They measure ~62 against a floor of 60, so a
    /// clause here would red on any innocent retune of the press
    /// step while catching no regression a user could see —
    /// tests.md's value-pin trap exactly. What DOES hold the
    /// press is its rank, which `KiwiProminentButtonStateTests`
    /// derives from the same tokens.
    @Test("the disabled fill separates from the live one")
    func disabledSeparatesFromRest() throws {
        let source = try themeSource()
        let accent = try fill("accent", in: source)
        let off = try fill("accentDisabled", in: source)
        let measured = try #require(
            ColorVision.separation(accent, off)
        )
        #expect(
            measured >= ColorVision.separationFloor,
            Comment(
                rawValue: String(
                    format:
                        "accent vs accentDisabled separates by "
                        + "%.1f under protanopia, under the %.0f "
                        + "floor — an unavailable button would "
                        + "still read as available",
                    measured,
                    ColorVision.separationFloor
                )
            )
        )
    }
}
