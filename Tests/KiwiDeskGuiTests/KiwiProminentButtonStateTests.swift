import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// What the pairing list cannot express: the seal's three states
/// as a ranked family, and the spelling that draws them.
///
/// `SettingsThemeContrastTests` measures each fill against the
/// ink one at a time, so it would stay green with disabled
/// brighter than pressed — a greyed button that reads as the
/// liveliest of the three. The ORDER is the invariant, and it is
/// derived from the shipped tokens rather than restated, so a
/// retune moves these numbers with it (#1198).
/// **Main-actor spend**, per tests.md: the two colour tests
/// resolve six tokens through AppKit and are `@MainActor` for
/// that alone; the source scan below is not, because a file read
/// and a string walk have no reason to sit in that queue.
@Suite("Kiwi prominent button states")
struct KiwiProminentButtonStateTests {
    /// Every ground the seal is drawn on. **Hand-kept, like the
    /// contrast suite's list**: a new seal site adds its ground
    /// here in the same change set, or the disabled fill's
    /// legibility on that ground is measured by nobody.
    ///
    /// The near-black pill and the light-mode page are opposite
    /// polarity, which is the whole difficulty — one opaque fill
    /// has to stay visible on both without moving with the
    /// appearance.
    private let grounds: [(String, Color)] = [
        ("savePill", SettingsTheme.savePill),
        ("page", SettingsTheme.page),
        ("card", SettingsTheme.card),
    ]

    /// rest > pressed > disabled, in both appearances.
    ///
    /// A pressed control is still ENABLED, so its label stays
    /// above the disabled one; a disabled control that outranked
    /// it would be saying the wrong thing in the one channel a
    /// colour-blind user still reads.
    @MainActor
    @Test("the label's contrast ranks rest > pressed > disabled")
    func stateContrastIsOrdered() throws {
        for dark in [false, true] {
            let rest = try ThemeContrast.contrast(
                SettingsTheme.accentInk,
                over: SettingsTheme.accent,
                inkAlpha: 1,
                dark: dark
            )
            let pressed = try ThemeContrast.contrast(
                SettingsTheme.accentInk,
                over: SettingsTheme.accentPressed,
                inkAlpha: 1,
                dark: dark
            )
            let off = try ThemeContrast.contrast(
                SettingsTheme.accentInk,
                over: SettingsTheme.accentDisabled,
                inkAlpha: 1,
                dark: dark
            )
            #expect(
                rest > pressed,
                Comment(
                    rawValue:
                        "\(dark ? "dark" : "light"): pressed "
                        + "\(pressed) does not sit below rest "
                        + "\(rest) — a press must read as a "
                        + "step down, not up"
                )
            )
            #expect(
                pressed > off,
                Comment(
                    rawValue:
                        "\(dark ? "dark" : "light"): disabled "
                        + "\(off) is not below pressed "
                        + "\(pressed) — the greyed state would "
                        + "read as the liveliest of the three"
                )
            )
        }
    }

    /// The disabled fill has to stay VISIBLE as a control, on a
    /// ground the style cannot know. 3.0 is the non-text floor
    /// the contrast suite already uses for marks — the fill is a
    /// mark, not text.
    @MainActor
    @Test("the disabled fill clears 3:1 on every seal ground")
    func disabledFillIsVisibleEverywhere() throws {
        for dark in [false, true] {
            for (name, ground) in grounds {
                let r = try ThemeContrast.contrast(
                    SettingsTheme.accentDisabled,
                    over: ground,
                    inkAlpha: 1,
                    dark: dark
                )
                #expect(
                    r >= 3.0,
                    Comment(
                        rawValue:
                            "disabled fill on \(name) "
                            + "(\(dark ? "dark" : "light")) is "
                            + "\(r):1 — the greyed button "
                            + "disappears into that ground"
                    )
                )
            }
        }
    }

    /// WHICH state draws WHICH token, and where `isEnabled` is
    /// read.
    ///
    /// `guard-prover` found the gap this closes (2026-09-06):
    /// exchanging the disabled and pressed tokens keeps every
    /// other guard green — all four are still named, the count
    /// of `.opacity(` is unchanged, the hexes and their ratios
    /// are untouched — while the render becomes #1198 wearing
    /// the other polarity, a disabled button in the live press
    /// green. The colour suites measure the tokens and the scan
    /// above measures their presence; the MAPPING falls between
    /// them.
    ///
    /// Contiguous needles, per tests.md: the tokens inside them
    /// are not value pins but the glue that binds each state to
    /// its own, which is the whole assertion. Reshaping the
    /// mapping reds this — re-point the needles once the render
    /// has been checked, rather than deleting them.
    @Test("each state draws its own token, read from a View")
    func statesMapToTheirOwnTokens() throws {
        let source = squashed(try sealSource())
        for needle in [
            "if!isEnabled{returnSettingsTheme.accentDisabled}",
            "configuration.isPressed"
                + "?SettingsTheme.accentPressed"
                + ":SettingsTheme.accent",
        ] {
            #expect(
                source.contains(needle),
                Comment(
                    rawValue:
                        "the seal's state mapping no longer "
                        + "reads `\(needle)` — a state drawing "
                        + "another state's token passes every "
                        + "other guard here"
                )
            )
        }
        // `@Environment` on the STYLE is not an observation
        // point, and disabled is the only state that drains the
        // accent — a stale read draws an available button that
        // refuses every click. So the property must sit inside
        // the nested view, never before it.
        let face = try #require(
            source.range(of: "privatestructFace:View{"),
            "the seal no longer reads its state from a View"
        )
        let env = try #require(
            source.range(of: "@Environment(\\.isEnabled)"),
            "the seal no longer reads isEnabled"
        )
        #expect(
            env.lowerBound > face.lowerBound,
            Comment(
                rawValue:
                    "isEnabled is read on the ButtonStyle "
                    + "rather than inside its View — not an "
                    + "observation point"
            )
        )
    }

    /// The seal's source, comment-stripped.
    private func sealSource() throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Onboarding/"
                    + "KiwiProminentButton.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(
            source.count > 200,
            "the seal read empty — the scan proves nothing"
        )
        return source
    }

    private func squashed(_ source: String) -> String {
        source.split(whereSeparator: \.isWhitespace).joined()
    }

    /// The spelling, not the value: every state is a token, and
    /// no state is an opacity.
    ///
    /// The ban sits on the file that would reintroduce it
    /// rather than on its callers; `docs/ui-patterns.md` ▸ the
    /// accent-fill exception carries why an opacity cannot draw
    /// a state here.
    @Test("every state is a token and none is an opacity")
    func statesAreTokensNotOpacity() throws {
        let source = try sealSource()
        for token in [
            "SettingsTheme.accent", "SettingsTheme.accentPressed",
            "SettingsTheme.accentDisabled",
            "SettingsTheme.accentInk",
        ] {
            #expect(
                source.contains(token),
                Comment(
                    rawValue:
                        "the seal no longer names \(token) — a "
                        + "state it does not draw from a token "
                        + "is drawn from the ground"
                )
            )
        }
        // The stroke's alpha is the one sanctioned use, and it
        // rides `accentInk` rather than the ground.
        #expect(
            source.occurrences(of: ".opacity(") == 1,
            Comment(
                rawValue:
                    "the seal spells .opacity( "
                    + "\(source.occurrences(of: ".opacity(")) "
                    + "times; only the accentInk stroke edge may "
                    + "— a state drawn as an opacity composites "
                    + "against a ground the style cannot know"
            )
        )
    }
}
