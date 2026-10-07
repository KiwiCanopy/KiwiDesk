import Foundation
import Testing

@testable import KiwiDeskCore

/// The update window's gold (#1542, #2038) marks — the Highlights
/// edge, its ★, the spotlight symbols — and never inks, so its
/// floor is colour-vision separation, as the mode-gated frame's
/// is (`ModeGatedFrameSeparationTests`), rather than a luminance
/// ratio: against the gold-washed card every mark sits on. (The
/// failed state's `warningInk` glyph never shares the window with
/// the gold — Failed steps the panel back to ink3.) Every input
/// is PARSED from the theme source, so a retune moves the guard
/// with it.
@Suite("Highlight gold separation (#2038)")
struct HighlightSeparationTests {
    private func themeSource() throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
            try #require(url.path != "/")
        }
        url.deleteLastPathComponent()
        let directory = url.appendingPathComponent(
            "Sources/KiwiDesk/Settings"
        )
        var source = ""
        for file in ["SettingsTheme.swift", "SettingsTheme+Metrics.swift"] {
            source += try String(
                contentsOf: directory.appendingPathComponent(file),
                encoding: .utf8
            )
        }
        return source.split(whereSeparator: \.isWhitespace).joined()
    }

    /// `token(light: 0xAA_BB_CC, dark: 0x…)` → the two hexes.
    private func token(
        _ name: String,
        in squashed: String
    ) throws -> (light: String, dark: String) {
        let start = try #require(
            squashed.range(of: "let\(name)=token(light:0x"),
            Comment(rawValue: name)
        )
        let rest = squashed[start.upperBound...]
        let parts = rest.split(separator: ",", maxSplits: 1)
        let light = String(parts[0]).replacingOccurrences(of: "_", with: "")
        let darkPart = try #require(
            String(parts[1]).range(of: "dark:0x").map {
                String(parts[1])[$0.upperBound...]
            }
        )
        let dark = darkPart.prefix { $0.isHexDigit || $0 == "_" }
            .replacingOccurrences(of: "_", with: "")
        try #require(light.count == 6 && dark.count == 6)
        return ("#" + light, "#" + dark)
    }

    private func washOpacity(in squashed: String) throws -> Double {
        let start = try #require(
            squashed.range(of: "lethighlightWashOpacity:CGFloat=")
        )
        let digits = squashed[start.upperBound...]
            .prefix { $0.isNumber || $0 == "." }
        return try #require(Double(digits))
    }

    /// The card as drawn under the panel: the gold at the wash
    /// opacity over `card`.
    private func washed(_ gold: String, over card: String, alpha: Double)
        throws -> String
    {
        let byte = String(format: "%02X", Int((alpha * 255).rounded()))
        return try #require(ColorVision.composite(gold + byte, over: card))
    }

    @Test("the gold separates from its washed card, both modes")
    func goldSeparatesFromWashedCard() throws {
        let source = try themeSource()
        let gold = try token("highlight", in: source)
        let card = try token("card", in: source)
        let alpha = try washOpacity(in: source)
        for (name, g, c) in [
            ("light", gold.light, card.light),
            ("dark", gold.dark, card.dark),
        ] {
            let ground = try washed(g, over: c, alpha: alpha)
            let sep = try #require(ColorVision.separation(g, ground))
            #expect(
                sep >= ColorVision.separationFloor,
                Comment(
                    rawValue:
                        "gold vs washed card (\(name)) separates "
                        + "\(sep) — under the floor; the edge and "
                        + "the symbols sink into the panel"
                )
            )
        }
    }
}
