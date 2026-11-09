import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiVision ▸ Maximize (#3064): a card of its own between Stays
/// clear and System appearance (owner, 2026-11-09), walking its
/// list, its picker offering every `VisionMaximize` in declared
/// order, and a lens page drawing the same card.
@Suite("KiwiVision Maximize card (#3064)")
struct KiwiVisionMaximizeCardTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static func squashed(_ path: String) throws -> String {
        let source = try SourceScan.blankedSource(
            at: root.appendingPathComponent(path)
        )
        return source.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the card sits between Stays clear and System appearance")
    func cardOrder() throws {
        let section = try Self.squashed(
            "Sources/KiwiDesk/Settings/Sections/KiwiVisionSection.swift"
        )
        let clear = try #require(section.range(of: "KiwiVisionClearCard("))
        let fill = try #require(
            section.range(of: "KiwiVisionMaximizeCard(")
        )
        let look = try #require(
            section.range(of: "KiwiVisionAppearanceCard(")
        )
        #expect(clear.lowerBound < fill.lowerBound)
        #expect(fill.lowerBound < look.lowerBound)
    }

    @Test("the card walks its list and renders its one row")
    func cardWalksItsList() throws {
        #expect(KiwiVisionRowOrder.maximize == [.kiwiVision(.maximize)])
        #expect(
            KiwiVisionRowOrder.byContainer[.kiwiVisionMaximize]
                == KiwiVisionRowOrder.maximize
        )
        let card = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionMaximizeCard.swift"
        )
        #expect(
            card.contains(
                "ForEach(KiwiVisionRowOrder.maximize,id:\\.id){keyin"
            )
        )
        #expect(card.contains("case.kiwiVision(.maximize):"))
    }

    @Test("the picker offers every fill in declared order")
    @MainActor func pickerOrder() {
        #expect(KiwiVisionMaximizeRow.order == VisionMaximize.allCases)
        #expect(KiwiVisionMaximizeRow.order.first == .off)
    }

    @Test("a lens page draws the Maximize card")
    func lensDrawsTheCard() throws {
        let overrides = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/KiwiVision/"
                + "KiwiVisionLensOverrides.swift"
        )
        #expect(
            overrides.contains(
                "SettingsSection(SettingsCatalog.kiwiVision.fillCard"
            )
        )
        #expect(overrides.contains("override(\\.maximize)"))
    }
}
