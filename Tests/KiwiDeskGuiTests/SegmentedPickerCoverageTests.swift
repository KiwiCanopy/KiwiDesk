import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// What the #823 migration is worth only if nothing undoes it:
/// the shared `SegmentedPicker` is the ONLY segmented chooser.
/// Its accent pill's ink is measured as "accentInk on accent" in
/// `SettingsThemeContrastTests`, the track (`trackFill`) with the
/// chips there (#2047).
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
            // KiwiHub's paint, whose default is `chipRest`
            // (`PanelGlassTests` ▸ `scopeSwitchReadsThePaint`).
            "?paint.rowHover:.clear",
        ] {
            #expect(source.contains(needle), Comment(rawValue: needle))
        }
        for banned in [".primary.opacity(", ".secondary.opacity("] {
            #expect(!source.contains(banned), Comment(rawValue: banned))
        }
    }

}
