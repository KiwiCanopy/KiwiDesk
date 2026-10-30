import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiHub's fills fade along the panel's axis to the shelf's own
/// highlight share (#2721): the paint takes that share from the
/// shelf, never one handed in, draws flat with no axis, and its
/// gradient's far stop is that share.
@Suite("KiwiHub paint fade (#2721)")
struct KiwiHubPaintFadeTests {
    private static let axis = (start: UnitPoint.top, end: UnitPoint.bottom)

    private func shelf() -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.fillColor = "#1A1A2EA5"
        shelf.highlightColor = "#564AB6"
        shelf.fillFade = 100
        return shelf
    }

    /// A bundled palette whose share rises under Increase Contrast,
    /// so a paint ignoring the flag reads a different share.
    private func discriminating() throws -> KiwiShelf {
        let shelves = PaletteCatalog.bundled().map { palette in
            var settings = TilingSettings()
            palette.apply(to: &settings)
            var shelf = settings.kiwishelf
            shelf.fillFade = 100
            return shelf
        }
        return try #require(
            shelves.first {
                $0.highlightFadeShare(increaseContrast: true)
                    != $0.highlightFadeShare(increaseContrast: false)
            }
        )
    }

    @Test("The paint fades to the shelf's share", arguments: [false, true])
    func paintTakesTheShelfShare(increaseContrast: Bool) throws {
        let shelf = try discriminating()
        let paint = KiwiHubPaint(
            shelf,
            divider: "#FFFFFF33",
            axis: Self.axis,
            increaseContrast: increaseContrast
        )
        let expected = shelf.highlightFadeShare(
            increaseContrast: increaseContrast
        )
        // A share of 1 is no fade: the paint draws flat.
        guard expected < 1 else {
            #expect(paint.fadeShare == nil)
            return
        }
        let share = try #require(paint.fadeShare)
        #expect(share == expected)
    }

    @Test("No axis, or the untinted paint, draws flat")
    func noAxisIsFlat() {
        let paint = KiwiHubPaint(
            shelf(),
            divider: "#FFFFFF33",
            axis: nil,
            increaseContrast: false
        )
        #expect(paint.fadeShare == nil)
        #expect(KiwiHubPaint().fadeShare == nil)
    }

    @Test("The gradient's far stop is the fade share")
    func farStopIsTheShare() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/KiwiHubPaint.swift"
                )
        ).filter { !$0.isWhitespace }
        #expect(source.contains("colors:[color,color.opacity(fadeShare)]"))
        #expect(source.occurrences(of: "LinearGradient(") == 1)
    }
}
