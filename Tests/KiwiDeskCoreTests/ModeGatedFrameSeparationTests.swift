import Foundation
import Testing

@testable import KiwiDeskCore

/// The mode-gated frame's colour-vision floors (#760): the
/// Settings mode-gated border draws the accent at
/// `modeGatedStrokeOpacity`, and that composited stroke must
/// separate — under protanopia, the strict axis — from the
/// plain `hairline` it neighbours on the same edge, over BOTH
/// grounds a card is drawn on: `card` at rest and `cardHover`
/// under the pointer. 0.5 measured at exactly the floor against
/// the light hairline, which is why the shipped value moved to
/// 0.6 (ui-designer, 2026-08-09). The edge's other neighbour
/// used to be hover's own full-strength accent; #1173 moved the
/// pointer off this channel entirely.
///
/// Lives in this target because `ColorVision` does; every input
/// is PARSED from `SettingsTheme.swift` — the hex pairs and the
/// opacity — so the guard follows a retune instead of pinning a
/// stale copy of it (a number-pin derives, never restates).
@Suite("Mode-gated frame separation")
struct ModeGatedFrameSeparationTests {
    private func themeSource() throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
            try #require(url.path != "/")
        }
        url.deleteLastPathComponent()
        // Both halves of the split declaration (Phase 4 moved
        // the CGFloat metrics to `+Metrics` at the §2.1
        // ceiling): the hex pairs live in the colour file, the
        // opacity in the metrics file, and this guard parses
        // one concatenated source so a further split cannot
        // strand either needle silently — `#require` still
        // fails loudly if a parse finds nothing.
        let directory = url.appendingPathComponent(
            "Sources/KiwiDesk/Settings"
        )
        var source = ""
        for file in [
            "SettingsTheme.swift",
            "SettingsTheme+Metrics.swift",
        ] {
            source += try String(
                contentsOf: directory.appendingPathComponent(
                    file
                ),
                encoding: .utf8
            )
        }
        try #require(!source.isEmpty)
        return source
    }

    /// `token(light: 0xAA_BB_CC, dark: …)` → the two hexes,
    /// whitespace-tolerant (`hairline` declares across lines).
    private func token(
        _ name: String,
        in source: String
    ) throws -> (light: String, dark: String) {
        let squashed =
            source
            .split(whereSeparator: \.isWhitespace)
            .joined()
        let needle = "let\(name)=token(light:0x"
        let start = try #require(
            squashed.range(of: needle),
            Comment(rawValue: name)
        )
        let rest = squashed[start.upperBound...]
        let parts = rest.split(separator: ",", maxSplits: 1)
        let light = String(parts[0]).replacingOccurrences(
            of: "_",
            with: ""
        )
        let darkPart = try #require(
            String(parts[1]).range(of: "dark:0x").map {
                String(parts[1])[$0.upperBound...]
            }
        )
        let dark =
            darkPart
            .prefix { $0.isHexDigit || $0 == "_" }
            .replacingOccurrences(of: "_", with: "")
        try #require(light.count == 6 && dark.count == 6)
        return ("#" + light, "#" + dark)
    }

    private func opacity(in source: String) throws -> Double {
        let squashed =
            source
            .split(whereSeparator: \.isWhitespace)
            .joined()
        let needle = "letmodeGatedStrokeOpacity:CGFloat="
        let start = try #require(squashed.range(of: needle))
        let digits = squashed[start.upperBound...]
            .prefix { $0.isNumber || $0 == "." }
        return try #require(Double(digits))
    }

    /// The stroke as rendered: accent at the shipped opacity,
    /// composited over the card fill it actually sits on.
    private func frame(
        accent: String,
        card: String,
        alpha: Double
    ) throws -> String {
        let byte = String(
            format: "%02X",
            Int((alpha * 255).rounded())
        )
        return try #require(
            ColorVision.composite(accent + byte, over: card)
        )
    }

    @Test("the frame separates from the hairline, both modes")
    func frameSeparatesFromHairline() throws {
        let source = try themeSource()
        let accent = try token("accent", in: source)
        let hairline = try token("hairline", in: source)
        let card = try token("card", in: source)
        let alpha = try opacity(in: source)
        for (a, h, c) in [
            (accent.light, hairline.light, card.light),
            (accent.dark, hairline.dark, card.dark),
        ] {
            let stroke = try frame(
                accent: a,
                card: c,
                alpha: alpha
            )
            let sep = try #require(
                ColorVision.separation(stroke, h)
            )
            #expect(
                sep >= ColorVision.separationFloor,
                Comment(
                    rawValue:
                        "mode-gated frame vs hairline "
                        + "separates \(Int(sep)) — under the "
                        + "floor; a protanope cannot tell an "
                        + "advanced card from a plain one"
                )
            )
        }
    }

    /// The same floor over the OTHER ground the frame is drawn
    /// on. Hover no longer touches this edge (#1173 moved the
    /// pointer to the fill), so "the rest frame reads as
    /// hovered" is no longer a thing that can happen — what
    /// replaces it is that a hovered card composites the same
    /// stroke over `cardHover` instead of `card`, and the
    /// marking has to keep separating from a plain card's
    /// hairline there too. A retune of `cardHover` is what this
    /// catches.
    @Test("the frame separates from the hairline over hover")
    func frameSeparatesOverTheHoverGround() throws {
        let source = try themeSource()
        let accent = try token("accent", in: source)
        let hairline = try token("hairline", in: source)
        let hover = try token("cardHover", in: source)
        let alpha = try opacity(in: source)
        for (a, h, c) in [
            (accent.light, hairline.light, hover.light),
            (accent.dark, hairline.dark, hover.dark),
        ] {
            let stroke = try frame(
                accent: a,
                card: c,
                alpha: alpha
            )
            let sep = try #require(
                ColorVision.separation(stroke, h)
            )
            #expect(
                sep >= ColorVision.separationFloor,
                Comment(
                    rawValue:
                        "mode-gated frame over the hover ground "
                        + "vs hairline separates \(Int(sep)) — "
                        + "under the floor; pointing at a marked "
                        + "card erases its marking"
                )
            )
        }
    }
}
