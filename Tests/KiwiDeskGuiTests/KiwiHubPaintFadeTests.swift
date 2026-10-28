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

    @Test("The paint fades to the shelf's share", arguments: [false, true])
    func paintTakesTheShelfShare(increaseContrast: Bool) throws {
        let shelf = shelf()
        let paint = KiwiHubPaint(
            shelf,
            divider: "#FFFFFF33",
            axis: Self.axis,
            increaseContrast: increaseContrast
        )
        let share = try #require(paint.fadeShare)
        let expected = shelf.highlightFadeShare(
            increaseContrast: increaseContrast
        )
        #expect(share == expected)
        #expect(share < 1)
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
