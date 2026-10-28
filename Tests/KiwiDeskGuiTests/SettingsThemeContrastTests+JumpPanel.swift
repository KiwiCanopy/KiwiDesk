import SwiftUI
import Testing

@testable import KiwiDesk

/// Jump to window's selected row (#1875 ▸ Ruling — the selected
/// row is the kiwi accent): an opaque accent fill whose inks are
/// fixed in both modes, as the fill is. The panel's ground is
/// glass, which has no hex, so `page` stands in for it — the
/// nearest opaque match for the `.regularMaterial` fallback. A
/// proxy: the glass branch is a device check.
extension SettingsThemeContrastTests {
    static let jumpPanel: [Pairing] = [
        Pairing(
            "accentInk on the selected Jump to window row",
            SettingsTheme.accentInk,
            on: SettingsTheme.accent
        ),
        Pairing(
            "accentInkSecondary on the selected Jump to window row",
            SettingsTheme.accentInkSecondary,
            on: SettingsTheme.accent
        ),
        // A row, tile or chip the pointer lifts (#2365): its
        // vibrant `.secondary` and `.tertiary` stand as `ink2` and
        // `ink3`; `.primary` on both lifts is the jump chips' `ink`.
        Pairing(
            "ink2 on a lifted KiwiHub row",
            SettingsTheme.ink2,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipRest]
        ),
        Pairing(
            "ink2 on a lifted KiwiHub chip",
            SettingsTheme.ink2,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipHover]
        ),
        // `.tertiary` names an item that cannot be applied: the
        // disabled floor.
        Pairing(
            "ink3 on a lifted KiwiHub chip",
            SettingsTheme.ink3,
            on: SettingsTheme.page,
            layers: [SettingsTheme.chipHover],
            floor: 3.0
        ),
        // The scope switch's chord hints (#2245): the selected
        // segment's is `accentInkSecondary` on the accent, above,
        // and a hovered one's is `ink`, which the segment
        // pairings measure.
        Pairing(
            "ink2 chord on the Jump scope switch's track",
            SettingsTheme.ink2,
            on: SettingsTheme.page,
            layers: [SettingsTheme.trackFill]
        ),
    ]

    /// The fill must read as a selection against the panel's ground
    /// — more than the container hairline separates from it, by
    /// luminance, which no colour-vision deficiency removes.
    @Test("the selected Jump row outreads the container hairline")
    func jumpSelectionOutreadsHairline() throws {
        for dark in [false, true] {
            let fill = try ThemeContrast.contrast(
                SettingsTheme.accent,
                over: SettingsTheme.page,
                inkAlpha: 1,
                dark: dark
            )
            let hairline = try ThemeContrast.contrast(
                SettingsTheme.hairline,
                over: SettingsTheme.page,
                inkAlpha: 1,
                dark: dark
            )
            #expect(
                fill > hairline,
                Comment(
                    rawValue: (dark ? "dark" : "light")
                        + String(
                            format: ": fill %.2f, hairline %.2f",
                            fill,
                            hairline
                        )
                )
            )
        }
    }

    /// The clauses above measure the token; this holds the row to
    /// drawing it, or a swapped fill passes both.
    @Test("the Jump row draws the measured selection fill")
    func jumpRowDrawsTheMeasuredFill() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpRowView.swift"
                    ),
                encoding: .utf8
            )
        )
        // The selection's fill, and the hover lift (#2365), both
        // through KiwiHub's paint (#2569), whose defaults are the
        // measured tokens.
        #expect(source.occurrences(of: ".fill(paint.fill(") == 2)
        #expect(source.occurrences(of: ".fill(paint.selection)") == 1)
        #expect(source.occurrences(of: ".fill(paint.rowHover)") == 1)
        let paint = try Self.hubPaint()
        #expect(paint.contains("var selection = SettingsTheme.accent\n"))
        #expect(paint.contains("var rowHover = SettingsTheme.chipRest\n"))
    }

    /// `KiwiHubPaint`'s source, comments stripped.
    private static func hubPaint() throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/KiwiHubPaint.swift"
                    ),
                encoding: .utf8
            )
        )
    }

    /// The row draws its measured inks on the fill, never the
    /// vibrant styles, which move with the appearance.
    @Test("the selected Jump row draws its measured inks")
    func jumpRowDrawsTheMeasuredInks() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpRowView.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(source.contains("paint.selectionInk)"))
        #expect(source.contains("paint.selectionInkSecondary)"))
        let paint = try Self.hubPaint()
        #expect(paint.contains("var selectionInk = SettingsTheme.accentInk\n"))
        #expect(
            paint.contains(
                "var selectionInkSecondary = SettingsTheme.accentInkSecondary"
            )
        )
    }
}
