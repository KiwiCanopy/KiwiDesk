import Foundation
import Testing

/// The two role groups stack where the window's rows stack
/// (#1857's ruling): side by side at 720 pt their localized
/// labels clip. The band is `SettingsWidthClass`'s, read once,
/// and the swap is one `AnyLayout` so the cards keep their
/// identity across it.
@Suite("Role groups stack at the narrow band")
struct RoleColorCardsLayoutTests {
    @Test("the role cards swap their axis on stacksRows")
    func cardsStackOnTheRowBand() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors/"
                    + "RoleColorCards.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
            .filter { !$0.isWhitespace }
        #expect(
            source.contains(
                "width.stacksRows?AnyLayout(VStackLayout("
            )
        )
        #expect(source.contains(":AnyLayout(HStackLayout("))
        // The swapped layout is the one that draws the cards.
        #expect(source.contains("layout{ForEach(ColorRole.allCases"))
        // One reading of the band, so the two arms cannot drift.
        #expect(source.components(separatedBy: "stacksRows").count == 2)
    }
}
