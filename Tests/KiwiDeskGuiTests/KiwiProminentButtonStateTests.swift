import AppKit
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
@MainActor
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

    /// WCAG contrast over tokens resolved under one appearance —
    /// the same resolution path `SettingsThemeContrastTests`
    /// takes, so the two suites measure one truth.
    private func ratio(
        _ ink: Color,
        on surface: Color,
        _ name: NSAppearance.Name
    ) throws -> Double {
        let a = try luminance(ink, name)
        let b = try luminance(surface, name)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func luminance(
        _ color: Color,
        _ name: NSAppearance.Name
    ) throws -> Double {
        let appearance = try #require(NSAppearance(named: name))
        var resolved: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(color).usingColorSpace(.sRGB)
        }
        let srgb = try #require(resolved)
        func lin(_ v: CGFloat) -> Double {
            let d = Double(v)
            return d <= 0.04045
                ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(srgb.redComponent)
            + 0.7152 * lin(srgb.greenComponent)
            + 0.0722 * lin(srgb.blueComponent)
    }

    /// rest > pressed > disabled, in both appearances.
    ///
    /// A pressed control is still ENABLED, so its label stays
    /// above the disabled one; a disabled control that outranked
    /// it would be saying the wrong thing in the one channel a
    /// colour-blind user still reads.
    @Test("the label's contrast ranks rest > pressed > disabled")
    func stateContrastIsOrdered() throws {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let rest = try ratio(
                SettingsTheme.accentInk,
                on: SettingsTheme.accent,
                appearance
            )
            let pressed = try ratio(
                SettingsTheme.accentInk,
                on: SettingsTheme.accentPressed,
                appearance
            )
            let off = try ratio(
                SettingsTheme.accentInk,
                on: SettingsTheme.accentDisabled,
                appearance
            )
            #expect(
                rest > pressed,
                Comment(
                    rawValue:
                        "\(appearance.rawValue): pressed "
                        + "\(pressed) does not sit below rest "
                        + "\(rest) — a press must read as a "
                        + "step down, not up"
                )
            )
            #expect(
                pressed > off,
                Comment(
                    rawValue:
                        "\(appearance.rawValue): disabled "
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
    @Test("the disabled fill clears 3:1 on every seal ground")
    func disabledFillIsVisibleEverywhere() throws {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            for (name, ground) in grounds {
                let r = try ratio(
                    SettingsTheme.accentDisabled,
                    on: ground,
                    appearance
                )
                #expect(
                    r >= 3.0,
                    Comment(
                        rawValue:
                            "disabled fill on \(name) "
                            + "(\(appearance.rawValue)) is "
                            + "\(r):1 — the greyed button "
                            + "disappears into that ground"
                    )
                )
            }
        }
    }

    /// The spelling, not the value: every state is a token, and
    /// no state is an opacity.
    ///
    /// `.opacity` over an unknown ground makes the drawn colour
    /// a function of the ground — it pressed darker on the
    /// tour's card and lighter on the save pill, and drained the
    /// label the style exists to keep readable. That is the
    /// #1198 defect one layer in, so the ban is on the file that
    /// would reintroduce it rather than on its callers.
    @Test("every state is a token and none is an opacity")
    func statesAreTokensNotOpacity() throws {
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
