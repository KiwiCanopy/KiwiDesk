import Foundation
import Testing

@testable import KiwiDeskCore

/// The mode-gated frame's colour-vision floors (#760): the
/// Settings mode-gated border draws the accent at
/// `modeGatedStrokeOpacity`, and that composited stroke must
/// separate — under protanopia, the strict axis — from both the
/// plain `hairline` it neighbours on the same edge and the
/// ground it sits on, over `card` at rest and `cardHover` under
/// the pointer. 0.5 measured at exactly the floor against the
/// light hairline, which is why the shipped value moved to 0.6
/// (ui-designer, 2026-08-09). The edge's other neighbour used
/// to be hover's own full-strength accent; #1173 moved the
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

    /// The frame's OTHER neighbour, and the one a retune can
    /// actually move. The clause here used to measure against
    /// hover's own full-strength accent, which #1173 took off
    /// this edge; measuring against the hairline over the hover
    /// ground was the obvious replacement and is INERT — the
    /// stroke carries 60% of the accent whatever it sits on, so
    /// no in-gamut ground brings it near a near-white hairline
    /// (guard-prover swept the cube: 83.3 is the reachable
    /// minimum against a floor of 60).
    ///
    /// What can fail is the frame sinking into the GROUND it is
    /// drawn on, which goes to 0 as the two converge — so this
    /// measures the stroke against each ground a card offers,
    /// `card` at rest and `cardHover` under the pointer. It is
    /// the #1173 invariant stated in colour: a marked card must
    /// still say so while the pointer is on it.
    @Test("the frame separates from the ground it sits on")
    func frameSeparatesFromItsGround() throws {
        let source = try themeSource()
        let accent = try token("accent", in: source)
        let card = try token("card", in: source)
        let hover = try token("cardHover", in: source)
        let alpha = try opacity(in: source)
        // Each ground is NAMED, not just spelled: the two
        // hexes go identical exactly when a retune collapses
        // one ground onto another, which is the failure this
        // clause is for — so the hex alone stops identifying
        // the arm at the moment it matters (guard-prover,
        // 2026-09-06). The separation prints undivided for the
        // same reason: truncating 55.7 to 55 reads as further
        // from the floor than it is.
        for (name, a, ground) in [
            ("card light", accent.light, card.light),
            ("card dark", accent.dark, card.dark),
            ("cardHover light", accent.light, hover.light),
            ("cardHover dark", accent.dark, hover.dark),
        ] {
            let stroke = try frame(
                accent: a,
                card: ground,
                alpha: alpha
            )
            let sep = try #require(
                ColorVision.separation(stroke, ground)
            )
            #expect(
                sep >= ColorVision.separationFloor,
                Comment(
                    rawValue:
                        "mode-gated frame vs \(name) "
                        + "(\(ground)) separates \(sep) — under "
                        + "the floor; the marking sinks into the "
                        + "card it marks"
                )
            )
        }
    }
}
