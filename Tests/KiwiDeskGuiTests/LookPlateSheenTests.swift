import Foundation
import Testing

/// The look card draws its ring WITH the sheen (owner ruling
/// 2026-09-28, #1684), read from the look-painted draft it is handed
/// — unlike the palette thumbnail, which withholds it at tile scale.
@Suite("Look card sheen")
struct LookPlateSheenTests {
    @Test("the card's ring paints the settings' sheen")
    func ringTakesTheSheen() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Looks/LookPlate.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
            .filter { !$0.isWhitespace }
        #expect(!source.isEmpty)
        let needle =
            "SheenPaint.style(settings.borderStyle.focusedColor,"
            + "sheen:settings.borderStyle.sheen)"
        #expect(source.components(separatedBy: needle).count - 1 == 1)
    }
}
