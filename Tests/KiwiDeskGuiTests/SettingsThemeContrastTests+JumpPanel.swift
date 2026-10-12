import SwiftUI
import Testing

@testable import KiwiDesk

/// Jump to window's selected row (#1875 ▸ Panel): a neutral fill,
/// never the accent, judged with `ColorVision` rather than by eye.
/// The panel's ground is glass, which has no hex, so `page` stands
/// in for it — the nearest opaque match for the `.regularMaterial`
/// fallback — and `ink` for the vibrant `.primary` the title
/// draws. A proxy: the glass branch is a device check.
extension SettingsThemeContrastTests {
    static let jumpPanel: [Pairing] = [
        Pairing(
            "ink on the selected Jump to window row",
            SettingsTheme.ink,
            on: SettingsTheme.page,
            layers: [SettingsTheme.rowSelected]
        )
    ]

    /// The fill must read as a selection against the panel's ground
    /// — more than the container hairline separates from it.
    @Test("the selected Jump row outreads the container hairline")
    func jumpSelectionOutreadsHairline() throws {
        for dark in [false, true] {
            let fill = try ThemeContrast.contrast(
                SettingsTheme.rowSelected,
                over: SettingsTheme.page,
                inkAlpha: try ThemeContrast.resolvedAlpha(
                    SettingsTheme.rowSelected,
                    dark: dark
                ),
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
        #expect(source.occurrences(of: ".fill(") == 1)
        #expect(
            source.occurrences(of: ".fill(SettingsTheme.rowSelected)")
                == 1
        )
    }
}
