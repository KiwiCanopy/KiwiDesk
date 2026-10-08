import AppKit
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// What the #823 migration is worth only if nothing undoes it:
/// the shared `SegmentedPicker` is the ONLY segmented chooser and
/// its accent pill keeps an ink that clears AA. The track is the
/// `trackFill` token, its labels measured with the chips
/// (`SettingsThemeContrastTests.chips`, #2047).
///
/// Split from `SettingsThemeContrastTests` because that suite is
/// at the §2.1 ceiling; the WCAG arithmetic below is a per-file
/// copy by the same convention its own helpers are (tests.md),
/// and it measures the same resolved-token truth.
@Suite("Segmented picker coverage (#823)")
@MainActor
struct SegmentedPickerCoverageTests {
    /// A native `.pickerStyle(.segmented)` is an
    /// `NSSegmentedControl`: AppKit draws its own track beside
    /// the window's capsules and picks the selected label's ink
    /// itself. Neither is visible to any colour lens — the ink
    /// is never written down, so `SettingsRawColorTests` sees no
    /// literal and `SettingsThemeContrastTests` can only weigh
    /// inks the tree actually draws. The header's mode segment
    /// and General's Appearance row shipped that way until #823
    /// and put near-white on the accent at ~2.4:1 in dark.
    ///
    /// So the ban is a source scan, with the usual `allowed` map
    /// for a site that earns an exemption — empty today, and an
    /// entry must say what makes the native control right there.
    /// Stated reach: the map is keyed on a file's NAME, so an
    /// entry would exempt every same-named file in the tree, and
    /// a style reached through a variable is invisible to any
    /// scan.
    @Test("no view takes the native segmented style")
    func nativeSegmentedStyleIsBanned() throws {
        let allowed: [String: String] = [:]
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        // A scan that read nothing would pass having looked at
        // nothing (#635).
        #expect(files.count > 50)
        for file in files {
            let name = file.lastPathComponent
            guard allowed[name] == nil else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
            // BOTH spellings: the shorthand and the legacy
            // `SegmentedPickerStyle()` initialiser, which is the
            // same control and passed the first cut green
            // (guard-prover, 2026-08-12). What a scan still
            // cannot see is `.pickerStyle(someVar)`.
            let native =
                source.contains(".pickerStyle(.segmented)")
                || source.contains(
                    ".pickerStyle(SegmentedPickerStyle())"
                )
            #expect(
                !native,
                Comment(
                    rawValue:
                        "\(name) takes the native segmented "
                        + "style — AppKit then draws its own "
                        + "track and picks the selected "
                        + "label's ink, which no colour lens "
                        + "can see. Use SegmentedPicker, or "
                        + "add an entry to `allowed` saying "
                        + "what makes the native control right "
                        + "here (#823)."
                )
            )
        }
    }

    /// The track and the segment lift are theme tokens (#2047),
    /// measured in `SettingsThemeContrastTests.chips`: the track's
    /// fill AND rim take `trackFill`, the unselected hover one
    /// `chipRest` step, and no bare opacity of a hierarchical
    /// colour paints beside them, whichever way it is spelled.
    @Test("the picker draws its track and lift from the theme")
    func trackAndLiftAreTokens() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common"
            )
            .appendingPathComponent("SegmentedPicker.swift")
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        for needle in [
            ".background(Capsule().fill(SettingsTheme.trackFill))",
            "Capsule().strokeBorder(SettingsTheme.trackFill,",
            "?SettingsTheme.chipRest:.clear",
        ] {
            #expect(source.contains(needle), Comment(rawValue: needle))
        }
        for banned in [".primary.opacity(", ".secondary.opacity("] {
            #expect(!source.contains(banned), Comment(rawValue: banned))
        }
    }

    /// The floor the pairing rests on, stated as the boundary
    /// rather than as today's value. `SettingsThemeContrastTests`
    /// asserts the shipped accent passes; it cannot say how much
    /// room is left, so an accent retune made for unrelated
    /// reasons — a brand tweak — would red only after crossing
    /// the line, with every other lens still green.
    ///
    /// Derived, not restated: the boundary is SOLVED from the
    /// shipped `accentInk` — WCAG's ratio is linear in the
    /// lighter luminance, so the AA point is
    /// `4.5 * (inkL + 0.05) - 0.05` — and the literal below is
    /// checked against that, never used as the source. The
    /// number also appears in #823's `ui-designer` ruling, which
    /// is prose nothing can guard; this is what makes it
    /// re-derivable.
    @Test("the accent keeps room above the AA boundary")
    func accentLuminanceFloor() throws {
        let ink = try resolved(SettingsTheme.accentInk)
        let accent = try resolved(SettingsTheme.accent)
        let inkLuminance = luminance(ink)
        // `accentInk` is the darker of the pair, so the ratio is
        // (accentL + 0.05) / (inkL + 0.05); AA at 4.5 is reached
        // when accentL = 4.5 * (inkL + 0.05) - 0.05.
        let boundary = 4.5 * (inkLuminance + 0.05) - 0.05
        #expect(
            abs(boundary - 0.244) < 0.001,
            Comment(
                rawValue: String(
                    format:
                        "the AA boundary moved to %.4f — "
                        + "accentInk changed, so the 0.244 this "
                        + "test and #823's ruling both name is "
                        + "stale",
                    boundary
                )
            )
        )
        #expect(
            luminance(accent) > boundary,
            Comment(
                rawValue: String(
                    format:
                        "accent luminance %.3f is under the "
                        + "%.3f floor — accentInk drops below "
                        + "AA on it, everywhere the pair is "
                        + "drawn",
                    luminance(accent),
                    boundary
                )
            )
        )
    }

    // MARK: - WCAG arithmetic over resolved tokens

    private func resolved(
        _ color: Color,
        dark: Bool = false
    ) throws -> (r: Double, g: Double, b: Double) {
        let appearance = try #require(
            NSAppearance(named: dark ? .darkAqua : .aqua)
        )
        var resolvedColor: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor =
                NSColor(color).usingColorSpace(.sRGB)
        }
        let srgb = try #require(resolvedColor)
        return (
            Double(srgb.redComponent),
            Double(srgb.greenComponent),
            Double(srgb.blueComponent)
        )
    }

    private func luminance(
        _ rgb: (r: Double, g: Double, b: Double)
    ) -> Double {
        func lin(_ v: Double) -> Double {
            v <= 0.04045
                ? v / 12.92
                : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(rgb.r) + 0.7152 * lin(rgb.g)
            + 0.0722 * lin(rgb.b)
    }
}
