import Foundation
import Testing

@testable import KiwiDesk

/// The Screens picture's CHROME is wired to its owners — the
/// geometry to `ScreenArrangement`, the drawn numbers to
/// `SettingsTheme` (#758).
///
/// Split from `ScreensGateWiringTests` (the gate, seam and
/// surfacing-branch needles) as that suite reached the 350-line
/// ceiling; same needle idiom — whitespace-squashed,
/// comment-stripped source, keyed on use sites.
@Suite("Screens chrome wiring")
struct ScreensChromeWiringTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    private func read(_ path: String) throws -> String {
        try String(
            contentsOf: settingsDir.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    /// Whitespace-free source, so a needle survives the formatter
    /// wrapping a call across lines.
    private func squashed(_ path: String) throws -> String {
        SourceScan.stripComments(try read(path))
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    /// The picture asks `ScreenArrangement` for its geometry and
    /// computes none of its own.
    ///
    /// This is the #702 rule one surface over: a drawing that
    /// re-derives what a shared function owns is right the day it
    /// is written and drifts the day the rule moves. Here the
    /// shared function is also the only thing the geometry guards
    /// can see — a card positioned by arithmetic inline in the
    /// view would pass every assertion in
    /// `ScreenArrangementTests` while drawing something else.
    @Test("the picture asks the arrangement for its geometry")
    func pictureAsksTheArrangement() throws {
        let name = "Components/Screens/ScreensPicture.swift"
        let source = try squashed(name)
        #expect(source.contains("ScreenArrangement.layout("))
        for forbidden in ["frame.minX", "frame.width", "NSScreen"] {
            #expect(
                !source.contains(forbidden),
                Comment(
                    rawValue:
                        "\(name) reads display geometry itself "
                        + "(`\(forbidden)`) instead of drawing "
                        + "the arrangement it was given"
                )
            )
        }
    }

    /// The picture's chrome reads its numbers from
    /// `SettingsTheme`, which is the one copy (#758) — a stand
    /// or stroke re-hardcoded beside the drawing is the drift
    /// the theme constants exist to end.
    ///
    /// The stroke needle is the WHOLE ternary: the rest-weight
    /// name is a substring of the selected-weight name, so a
    /// bare `screenCardStroke` check would stay green with the
    /// rest weight hardcoded back to a literal.
    @Test("the chrome reads its themed metrics")
    func chromeReadsThemedMetrics() throws {
        let picture = try squashed(
            "Components/Screens/ScreensPicture.swift"
        )
        for needle in [
            "SettingsTheme.screenStandScale",
            "SettingsTheme.screenStandMin",
            "SettingsTheme.screenStandMax",
            "SettingsTheme.screenNeckScale",
            "SettingsTheme.screenNeckMin",
            "SettingsTheme.screenNeckMax",
        ] {
            #expect(
                picture.contains(needle),
                Comment(
                    rawValue:
                        "ScreensPicture no longer reads "
                        + "`\(needle)` — the stand's size went "
                        + "inline"
                )
            )
        }
        let card = try squashed(
            "Components/Screens/ScreenCard.swift"
        )
        #expect(
            card.contains(
                "SettingsTheme.screenCardStrokeSelected"
                    + ":SettingsTheme.screenCardStroke)"
            ),
            Comment(
                rawValue:
                    "ScreenCard's border no longer takes both "
                    + "weights from SettingsTheme"
            )
        )
    }

    /// The picture places itself where `ScreenArrangement.origin`
    /// says, so the centring the geometry suite proves is the
    /// centring drawn (#2065).
    @Test("the picture is placed at the arrangement's origin")
    func pictureTakesTheOrigin() throws {
        let picture = try squashed(
            "Components/Screens/ScreensPicture.swift"
        )
        for needle in [
            "ScreenArrangement.origin(of:layout.contentSize,in:canvas)",
            ".padding(.leading,origin.x).padding(.top,origin.y)",
            "letlayout=arrangement(for:canvas)",
        ] {
            #expect(picture.contains(needle), "lost `\(needle)`")
        }
    }

    /// The tray's wrap arithmetic measures the row with
    /// `chipArea`, the width the cards' capacity counts, rather
    /// than a second spelling of it (#2065 review).
    @Test("the tray height measures rows with chipArea")
    func trayHeightTakesTheChipArea() throws {
        let tray = try squashed(
            "Components/Screens/ScreenArrangement+Tray.swift"
        )
        #expect(tray.contains("ScreenCardChips.chipArea("))
        #expect(!tray.contains("cardPadding"))
    }
}
